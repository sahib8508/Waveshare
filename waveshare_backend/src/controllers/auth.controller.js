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
      to: phone.startsWith('+') ? phone : `+91${phone}`,
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

// ✅ FIXED: Document Upload with proper error handling
// ✅ FIXED: Document Upload with proper error handling and data return
exports.uploadDocument = [
  upload.single('document'),
  async (req, res) => {
    try {
      const { orgId, documentType } = req.body;
      const file = req.file;

      console.log('📄 Document upload request:', { orgId, documentType, hasFile: !!file });

      // Validate inputs
      if (!orgId) {
        return res.status(400).json({
          success: false,
          message: 'Organization ID is required',
        });
      }

      if (!documentType) {
        return res.status(400).json({
          success: false,
          message: 'Document type is required',
        });
      }

      if (!file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
        });
      }

      // Find organization
      const org = await Organization.findOne({ orgId });
      if (!org) {
        return res.status(404).json({
          success: false,
          message: 'Organization not found',
        });
      }

      console.log('📤 Uploading to S3...');

      // Upload to S3
      const fileName = `${orgId}_${Date.now()}_${file.originalname}`;
      const uploadParams = {
        Bucket: process.env.S3_BUCKET_NAME,
        Key: `documents/${fileName}`,
        Body: file.buffer,
        ContentType: file.mimetype,
      };

      await s3Client.send(new PutObjectCommand(uploadParams));

      console.log('✅ S3 upload successful');

      // Update organization
      const documentUrl = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/documents/${fileName}`;
      org.documentUrl = documentUrl;
      org.documentType = documentType;
      org.verificationStatus = 'fully_verified';
      await org.save();

      console.log('✅ Document uploaded and org updated');
      console.log('📤 Returning data:', {
        orgCode: org.orgCode,
        adminId: org.adminId,
        orgName: org.orgName,
      });

      // ✅ CRITICAL: Return all required fields
      return res.status(200).json({
        success: true,
        message: 'Document uploaded successfully',
        orgCode: org.orgCode,
        adminId: org.adminId,
        orgName: org.orgName,
        documentUrl: documentUrl,
      });
    } catch (error) {
      console.error('❌ Document upload error:', error);
      return res.status(500).json({
        success: false,
        message: 'Upload failed: ' + error.message,
        error: error.message,
      });
    }
  },
];

// ✅ FIXED: Skip Document with proper data return
exports.skipDocument = async (req, res) => {
  try {
    const { orgId } = req.body;

    console.log('⏭️ Skip document request:', { orgId });

    if (!orgId) {
      return res.status(400).json({
        success: false,
        message: 'Organization ID is required',
      });
    }

    const org = await Organization.findOne({ orgId });
    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Organization not found',
      });
    }

    org.verificationStatus = 'fully_verified';
    await org.save();

    console.log('✅ Document skipped, org verified');
    console.log('📤 Returning data:', {
      orgCode: org.orgCode,
      adminId: org.adminId,
      orgName: org.orgName,
    });

    // ✅ CRITICAL: Return all required fields with status 200
    return res.status(200).json({
      success: true,
      message: 'Registration completed',
      orgCode: org.orgCode,
      adminId: org.adminId,
      orgName: org.orgName,
    });
  } catch (error) {
    console.error('❌ Skip document error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error: ' + error.message,
      error: error.message,
    });
  }
};

exports.testS3 = async (req, res) => {
  try {
    const testParams = {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: 'test.txt',
      Body: 'Hello from WaveShare!',
      ContentType: 'text/plain',
    };

    await s3Client.send(new PutObjectCommand(testParams));

    res.json({
      success: true,
      message: 'S3 connection working!',
      url: `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/test.txt`,
    });
  } catch (error) {
    console.error('S3 Test Error:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
// Add these to your auth.controller.js

// CSV Upload Handler


// ✅ FIXED CSV UPLOAD - Handles both students and teachers properly
// ✅ FIXED CSV UPLOAD - Handles both students and teachers properly
exports.uploadCSV = [
  upload.single('csvFile'),
  async (req, res) => {
    try {
      const { orgId, csvType } = req.body;
      const file = req.file;

      console.log('📊 CSV Upload Request:');
      console.log('  - orgId:', orgId);
      console.log('  - csvType:', csvType);
      console.log('  - File:', file?.originalname);
      console.log('  - File size:', file?.size);

      // Validation
      if (!orgId || !csvType || !file) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields (orgId, csvType, or file)',
        });
      }

      if (csvType !== 'students' && csvType !== 'teachers') {
        return res.status(400).json({
          success: false,
          message: 'Invalid CSV type. Must be "students" or "teachers"',
        });
      }

      // Find organization
      const org = await Organization.findOne({ orgId });
      if (!org) {
        return res.status(404).json({
          success: false,
          message: 'Organization not found',
        });
      }

      console.log('✅ Organization found:', org.orgName);

      // Generate S3 key with proper path
      const timestamp = Date.now();
      const fileName = `${orgId}_${csvType}_${timestamp}.csv`;
      const s3Key = `csv/${csvType}/${fileName}`;

      // Upload to S3 with proper parameters
      const uploadParams = {
        Bucket: process.env.S3_BUCKET_NAME,
        Key: s3Key,
        Body: file.buffer,
        ContentType: 'text/csv',
        ContentDisposition: 'inline',
      };

      console.log('📤 Uploading to S3...');
      console.log('  - Bucket:', process.env.S3_BUCKET_NAME);
      console.log('  - Key:', s3Key);
      console.log('  - Size:', file.size, 'bytes');

      const command = new PutObjectCommand(uploadParams);
      await s3Client.send(command);

      console.log('✅ S3 upload successful');

      // Parse CSV to count members
      const csvContent = file.buffer.toString('utf-8');
      const lines = csvContent.split('\n').filter(line => line.trim());
      const memberCount = Math.max(0, lines.length - 1); // Exclude header

      console.log(`📊 Parsed: ${memberCount} ${csvType}`);

      // Generate full S3 URL
      const csvUrl = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${s3Key}`;

      // Update organization based on type
      if (csvType === 'students') {
        org.studentsCSVUrl = csvUrl;
        org.totalStudents = memberCount;
        console.log('✅ Updated students:', memberCount);
      } else {
        org.teachersCSVUrl = csvUrl;
        org.totalTeachers = memberCount;
        console.log('✅ Updated teachers:', memberCount);
      }

      // Mark CSV as uploaded
      org.hasCSVUploaded = true;
      org.csvUploadedAt = new Date();
      
      await org.save();
      console.log('✅ Database updated successfully');

      return res.status(200).json({
        success: true,
        message: `${csvType} CSV uploaded successfully`,
        memberCount: memberCount,
        csvUrl: csvUrl,
        totalStudents: org.totalStudents || 0,
        totalTeachers: org.totalTeachers || 0,
      });

    } catch (error) {
      console.error('❌ CSV upload error:', error);
      console.error('Error details:', error.message);
      console.error('Stack trace:', error.stack);
      
      return res.status(500).json({
        success: false,
        message: 'Upload failed: ' + error.message,
        error: error.message,
      });
    }
  },
];

// Updated Admin Login (checks CSV status)
// ✅ COMPLETE ADMIN LOGIN - Checks verification, CSV status, returns all data
exports.adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    console.log('🔑 Login attempt:', { email });

    // Validation
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password required',
      });
    }

    // Find organization by adminEmail
    const org = await Organization.findOne({ adminEmail: email });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Email not found',
      });
    }

    // Check verification status
    if (org.verificationStatus !== 'fully_verified') {
      return res.status(403).json({
        success: false,
        message: 'Please complete registration first',
        verificationStatus: org.verificationStatus,
      });
    }

    // Verify password
    if (org.adminPassword !== password) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password',
      });
    }

    console.log('✅ Login successful for:', org.orgName);

    // Return complete org data with CSV status
    return res.status(200).json({
      success: true,
      message: 'Login successful',
      org: {
        orgId: org.orgId,
        orgName: org.orgName,
        orgCode: org.orgCode,
        orgType: org.orgType,
        adminId: org.adminId,
        adminName: org.adminName,
        adminEmail: org.adminEmail,
        adminPhone: org.adminPhone,
        emailDomain: org.emailDomain,
        
        // CSV Upload Status
        hasCSVUploaded: org.hasCSVUploaded || false,
        totalStudents: org.totalStudents || 0,
        totalTeachers: org.totalTeachers || 0,
        studentsCSVUrl: org.studentsCSVUrl || null,
        teachersCSVUrl: org.teachersCSVUrl || null,
        csvUploadedAt: org.csvUploadedAt || null,
        
        // Document Status
        documentUrl: org.documentUrl || null,
        documentType: org.documentType || null,
        verificationStatus: org.verificationStatus,
      },
    });
  } catch (error) {
    console.error('❌ Login error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error: ' + error.message,
    });
  }
};


// Add to auth.controller.js
exports.testCSVUpload = async (req, res) => {
  try {
    console.log('🧪 Testing S3 connection...');
    console.log('Bucket:', process.env.S3_BUCKET_NAME);
    console.log('Region:', process.env.AWS_REGION);
    console.log('Access Key ID:', process.env.AWS_ACCESS_KEY_ID ? 'SET' : 'NOT SET');
    console.log('Secret Key:', process.env.AWS_SECRET_ACCESS_KEY ? 'SET' : 'NOT SET');

    const testContent = 'unique_id,name,role\nTEST001,Test User,Student';
    const fileName = `test_${Date.now()}.csv`;

    const uploadParams = {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: `csv/${fileName}`,
      Body: Buffer.from(testContent),
      ContentType: 'text/csv',
    };

    const command = new PutObjectCommand(uploadParams);
    await s3Client.send(command);

    const url = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/csv/${fileName}`;

    res.json({
      success: true,
      message: 'Test CSV uploaded successfully!',
      url: url,
    });
  } catch (error) {
    console.error('Test failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack,
    });
  }
};

// In auth.controller.js
exports.testS3Connection = async (req, res) => {
  try {
    console.log('🧪 Testing S3...');
    console.log('Bucket:', process.env.S3_BUCKET_NAME);
    console.log('Region:', process.env.AWS_REGION);
    
    const testContent = 'name,email\nTest User,test@example.com';
    const fileName = `test_${Date.now()}.csv`;
    const s3Key = `csv/test/${fileName}`;

    const uploadParams = {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: s3Key,
      Body: Buffer.from(testContent),
      ContentType: 'text/csv',
    };

    const command = new PutObjectCommand(uploadParams);
    await s3Client.send(command);

    const url = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${s3Key}`;

    res.json({
      success: true,
      message: 'S3 connection working!',
      url: url,
    });
  } catch (error) {
    console.error('❌ S3 Test failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

