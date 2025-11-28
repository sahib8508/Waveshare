const Organization = require('../models/Organization');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const s3Client = require('../config/aws');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });
const twilio = require('twilio');

// =============================================================================
// TWILIO SMS SETUP
// =============================================================================
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

// Send SMS via Twilio
async function sendSMS(phone, otp) {
  try {
    await twilioClient.messages.create({
      body: `Your WaveShare verification code is: ${otp}. Valid for 10 minutes.`,
      from: process.env.TWILIO_PHONE_NUMBER,
      to: phone.startsWith('+') ? phone : `+91${phone}`, // Add +91 if missing
    });
    return true;
  } catch (error) {
    console.error('❌ SMS Error:', error.message);
    return false;
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function generateOrgCode(orgName) {
  const prefix = orgName.substring(0, 3).toUpperCase().replace(/[^A-Z]/g, 'X');
  const randomPart = crypto.randomBytes(3).toString('hex').toUpperCase().substring(0, 5);
  return `WAVE-${prefix}-${randomPart}`;
}

function generateOrgId() {
  return `ORG_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

function generateAdminId(orgCode) {
  const orgPart = orgCode.split('-')[1];
  return `ADM-${orgPart}-001`;
}

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

async function sendOTPEmail(email, name, otp) {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Your WaveShare Email Verification Code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4F46E5;">WaveShare Verification</h2>
        <p>Hello ${name},</p>
        <p>Your verification code is:</p>
        <div style="background: #F3F4F6; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #4F46E5; border-radius: 8px; margin: 20px 0;">
          ${otp}
        </div>
        <p style="color: #6B7280;">This code will expire in 10 minutes.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    console.error('Email error:', error);
    return false;
  }
}

// =============================================================================
// REGISTRATION FLOW
// =============================================================================

exports.registerOrganization = async (req, res) => {
  try {
    const { orgName, orgType, emailDomain, adminEmail, adminName, adminPhone, password } = req.body;

    console.log('📝 Registration:', { orgName, adminEmail });

    if (!orgName || !orgType || !emailDomain || !adminEmail || !adminName || !adminPhone || !password) {
      return res.status(400).json({
        success: false,
        message: 'All fields are required',
      });
    }

    const existing = await Organization.findOne({
      $or: [{ adminEmail }, { emailDomain }],
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'Organization already exists',
      });
    }

    const orgId = generateOrgId();
    const orgCode = generateOrgCode(orgName);
    const adminId = generateAdminId(orgCode);
    const emailOTP = generateOTP();

    console.log('🔑 Generated:', { orgId, orgCode, adminId });

    const newOrg = new Organization({
      orgId,
      orgName,
      orgType,
      orgCode,
      emailDomain,
      adminId,
      adminEmail,
      adminName,
      adminPhone,
      adminPassword: password,
      emailOTP: {
        code: emailOTP,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
      verificationStatus: 'pending',
    });

    await newOrg.save();

    const emailSent = await sendOTPEmail(adminEmail, adminName, emailOTP);

    console.log(emailSent ? '✅ Email sent' : '⚠️ Email failed');

    res.status(201).json({
      success: true,
      message: 'OTP sent to email',
      orgId: newOrg.orgId,
      orgCode: newOrg.orgCode,
      adminId: adminId,
      orgName: newOrg.orgName,
    });

  } catch (error) {
    console.error('❌ Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
};

exports.verifyEmailOTP = async (req, res) => {
  try {
    const { orgId, otp } = req.body;

    console.log('📧 Email verification:', { orgId, otp });

    if (!orgId || !otp) {
      return res.status(400).json({
        success: false,
        message: 'OrgID and OTP required',
      });
    }

    const org = await Organization.findOne({ orgId });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    if (new Date() > org.emailOTP.expiresAt) {
      return res.status(400).json({
        success: false,
        message: 'OTP expired',
      });
    }

    if (org.emailOTP.code !== otp) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP',
      });
    }

    const phoneOTP = generateOTP();
    org.verificationStatus = 'email_verified';
    org.phoneOTP = {
      code: phoneOTP,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    };
    await org.save();

    // 🔥 SEND ACTUAL SMS
    const smsSent = await sendSMS(org.adminPhone, phoneOTP);

    console.log(smsSent ? '✅ SMS sent' : '⚠️ SMS failed');

    res.json({
      success: true,
      message: 'Email verified. SMS sent to phone.',
      adminPhone: org.adminPhone,
      orgCode: org.orgCode,
      adminId: org.adminId,
      orgName: org.orgName,
    });

  } catch (error) {
    console.error('❌ Email verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
};

exports.resendEmailOTP = async (req, res) => {
  try {
    const { orgId } = req.body;

    const org = await Organization.findOne({ orgId });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    const emailOTP = generateOTP();
    org.emailOTP = {
      code: emailOTP,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    };
    await org.save();

    await sendOTPEmail(org.adminEmail, org.adminName, emailOTP);

    console.log('📧 Resent email OTP');

    res.json({
      success: true,
      message: 'OTP sent to email',
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
};

exports.verifyPhoneOTP = async (req, res) => {
  try {
    const { orgId, otp } = req.body;

    console.log('📱 Phone verification:', { orgId, otp });

    const org = await Organization.findOne({ orgId });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    if (new Date() > org.phoneOTP.expiresAt) {
      return res.status(400).json({
        success: false,
        message: 'OTP expired',
      });
    }

    if (org.phoneOTP.code !== otp) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP',
      });
    }

    org.verificationStatus = 'phone_verified';
    await org.save();

    console.log('✅ Phone verified');

    res.json({
      success: true,
      message: 'Phone verified',
      orgCode: org.orgCode,
      adminId: org.adminId,
      orgName: org.orgName,
    });

  } catch (error) {
    console.error('❌ Phone verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
};

exports.resendPhoneOTP = async (req, res) => {
  try {
    const { orgId } = req.body;

    const org = await Organization.findOne({ orgId });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    const phoneOTP = generateOTP();
    org.phoneOTP = {
      code: phoneOTP,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    };
    await org.save();

    // 🔥 SEND SMS
    await sendSMS(org.adminPhone, phoneOTP);

    console.log('📱 Resent phone OTP');

    res.json({
      success: true,
      message: 'OTP sent to phone',
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
};

exports.uploadDocument = [
  upload.single('document'),
  async (req, res) => {
    try {
      const { orgId, documentType } = req.body;
      const file = req.file;

      console.log('📄 Document upload:', { orgId, documentType });

      if (!file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
        });
      }

      const org = await Organization.findOne({ orgId });
      if (!org) {
        return res.status(404).json({
          success: false,
          message: 'Organization not found',
        });
      }

      const fileName = `${orgId}_${Date.now()}_${file.originalname}`;
      const uploadParams = {
        Bucket: process.env.S3_BUCKET_NAME,
        Key: `documents/${fileName}`,
        Body: file.buffer,
        ContentType: file.mimetype,
      };

      await s3Client.send(new PutObjectCommand(uploadParams));

      org.documentUrl = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/documents/${fileName}`;
      org.documentType = documentType;
      org.verificationStatus = 'fully_verified';
      await org.save();

      console.log('✅ Document uploaded');

      res.json({
        success: true,
        message: 'Document uploaded',
        orgCode: org.orgCode,
        adminId: org.adminId,
        orgName: org.orgName,
      });
    } catch (error) {
      console.error('❌ Document upload error:', error);
      res.status(500).json({
        success: false,
        message: 'Upload failed',
        error: error.message,
      });
    }
  },
];

exports.skipDocument = async (req, res) => {
  try {
    const { orgId } = req.body;

    const org = await Organization.findOne({ orgId });
    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    org.verificationStatus = 'fully_verified';
    await org.save();

    res.json({
      success: true,
      message: 'Document skipped',
      orgCode: org.orgCode,
      adminId: org.adminId,
      orgName: org.orgName,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
};

exports.adminLogin = async (req, res) => {
  try {
    const { adminId, password } = req.body;

    console.log('🔑 Login:', { adminId });

    if (!adminId || !password) {
      return res.status(400).json({
        success: false,
        message: 'Admin ID and password required',
      });
    }

    const org = await Organization.findOne({ adminId });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Admin ID not found',
      });
    }

    if (org.verificationStatus !== 'fully_verified') {
      return res.status(403).json({
        success: false,
        message: 'Complete registration first',
      });
    }

    if (org.adminPassword !== password) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password',
      });
    }

    console.log('✅ Login successful');

    res.json({
      success: true,
      message: 'Login successful',
      org: {
        orgId: org.orgId,
        orgName: org.orgName,
        orgCode: org.orgCode,
        adminId: org.adminId,
        adminName: org.adminName,
        adminEmail: org.adminEmail,
        stats: org.stats,
      },
    });

  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
};