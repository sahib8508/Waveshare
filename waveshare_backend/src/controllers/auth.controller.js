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
// controllers/auth.controller.js

// ✅ SINGLE CSV UPLOAD WITH AUTOMATIC HIERARCHY PARSING
// controllers/auth.controller.js
// FIND exports.uploadCSV and REPLACE with this:

exports.uploadCSV = [
  upload.single('csvFile'),
  async (req, res) => {
    try {
      const { orgId } = req.body;
      const file = req.file;

      console.log('📊 CSV Upload:', { orgId, fileName: file?.originalname });

      if (!orgId || !file) {
        return res.status(400).json({ success: false, message: 'Missing data' });
      }

      const org = await Organization.findOne({ orgId });
      if (!org) {
        return res.status(404).json({ success: false, message: 'Org not found' });
      }

      // Upload to S3
      const timestamp = Date.now();
      const fileName = `${orgId}_members_${timestamp}.csv`;
      const s3Key = `csv/members/${fileName}`;

      await s3Client.send(new PutObjectCommand({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: s3Key,
        Body: file.buffer,
        ContentType: 'text/csv',
      }));

      const csvUrl = `https://${process.env.S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${s3Key}`;
      console.log('✅ CSV uploaded to S3');

      // Parse CSV
      const csvContent = file.buffer.toString('utf-8');
      const lines = csvContent.split('\n').filter(line => line.trim());
      const dataLines = lines.slice(1); // Skip header
      
      const hierarchy = {
        totalMembers: 0,
        totalStudents: 0,
        totalFaculty: 0,
        totalStaff: 0,
        departments: {}
      };

      // Parse each line
      for (const line of dataLines) {
        const parts = line.split(',').map(p => p.trim());
        const [uniqueId, name, role, dept, branch, year, sem, section] = parts;
        
        if (!uniqueId || !role || !dept) continue;

        hierarchy.totalMembers++;
        
        if (role.toLowerCase() === 'student') hierarchy.totalStudents++;
        else if (role.toLowerCase() === 'supervisor') hierarchy.totalFaculty++;
        else hierarchy.totalStaff++;

        // Build department
        if (!hierarchy.departments[dept]) {
          hierarchy.departments[dept] = { name: dept, totalMembers: 0, branches: {} };
        }
        hierarchy.departments[dept].totalMembers++;

        // Build branch (students only)
        if (role.toLowerCase() === 'student' && branch) {
          if (!hierarchy.departments[dept].branches[branch]) {
            hierarchy.departments[dept].branches[branch] = { 
              name: branch, totalMembers: 0, years: {} 
            };
          }
          hierarchy.departments[dept].branches[branch].totalMembers++;

          // Build year
          if (year) {
            const yearKey = year;
            if (!hierarchy.departments[dept].branches[branch].years[yearKey]) {
              hierarchy.departments[dept].branches[branch].years[yearKey] = { 
                year: parseInt(year), semesters: {} 
              };
            }

            // Build semester
            if (sem) {
              const semKey = sem;
              if (!hierarchy.departments[dept].branches[branch].years[yearKey].semesters[semKey]) {
                hierarchy.departments[dept].branches[branch].years[yearKey].semesters[semKey] = { 
                  semester: parseInt(sem), sections: {} 
                };
              }

              // Build section
              if (section) {
                if (!hierarchy.departments[dept].branches[branch].years[yearKey].semesters[semKey].sections[section]) {
                  hierarchy.departments[dept].branches[branch].years[yearKey].semesters[semKey].sections[section] = {
                    section: section, totalMembers: 0
                  };
                }
                hierarchy.departments[dept].branches[branch].years[yearKey].semesters[semKey].sections[section].totalMembers++;
              }
            }
          }
        }
      }

      // Convert to arrays
      const departmentsArray = Object.values(hierarchy.departments).map(dept => ({
        name: dept.name,
        totalMembers: dept.totalMembers,
        branches: Object.values(dept.branches).map(branch => ({
          name: branch.name,
          totalMembers: branch.totalMembers,
          years: Object.values(branch.years).map(year => ({
            year: year.year,
            semesters: Object.values(year.semesters).map(sem => ({
              semester: sem.semester,
              sections: Object.values(sem.sections)
            }))
          }))
        }))
      }));

      // Save to database
      org.membersCSVUrl = csvUrl;
      org.csvUploadedAt = new Date();
      org.hasCSVUploaded = true;
      org.hierarchy = {
        totalMembers: hierarchy.totalMembers,
        totalStudents: hierarchy.totalStudents,
        totalFaculty: hierarchy.totalFaculty,
        totalStaff: hierarchy.totalStaff,
        departments: departmentsArray
      };

      await org.save();

      console.log('✅ Hierarchy saved');

      return res.status(200).json({
        success: true,
        message: 'CSV uploaded and hierarchy created',
        stats: {
          totalMembers: hierarchy.totalMembers,
          totalStudents: hierarchy.totalStudents,
          totalFaculty: hierarchy.totalFaculty,
          departments: departmentsArray.length
        }
      });

    } catch (error) {
      console.error('❌ CSV error:', error);
      return res.status(500).json({ success: false, message: error.message });
    }
  }
];

// Updated Admin Login (checks CSV status)
// ✅ COMPLETE ADMIN LOGIN - Checks verification, CSV status, returns all data

// FIND exports.adminLogin and REPLACE ENTIRE FUNCTION:

exports.adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    console.log('🔑 Login attempt:', { email });

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password required',
      });
    }

    const org = await Organization.findOne({ adminEmail: email });

    if (!org) {
      return res.status(404).json({
        success: false,
        message: 'Email not found',
      });
    }

    if (org.verificationStatus !== 'fully_verified') {
      return res.status(403).json({
        success: false,
        message: 'Please complete registration first',
      });
    }

    if (org.adminPassword !== password) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password',
      });
    }

    console.log('✅ Login successful');
    console.log('📊 Org data:', {
      hasCSV: org.hasCSVUploaded,
      totalMembers: org.hierarchy?.totalMembers || 0,
      totalStudents: org.hierarchy?.totalStudents || 0,
      totalFaculty: org.hierarchy?.totalFaculty || 0,
      hasHierarchy: !!org.hierarchy
    });

    // ✅ CRITICAL FIX: Return complete hierarchy
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
        
        // CSV Status
        hasCSVUploaded: org.hasCSVUploaded || false,
        csvUploadedAt: org.csvUploadedAt || null,
        
        // Hierarchy Stats
        totalMembers: org.hierarchy?.totalMembers || 0,
        totalStudents: org.hierarchy?.totalStudents || 0,
        totalFaculty: org.hierarchy?.totalFaculty || 0,
        totalStaff: org.hierarchy?.totalStaff || 0,
        
        // ✅ CRITICAL: Full Hierarchy Object
        hierarchy: org.hierarchy || null,
        
        verificationStatus: org.verificationStatus,
      },
    });
  } catch (error) {
    console.error('❌ Login error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
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

exports.verifyOrgCode = async (req, res) => {
  try {
    const { orgCode } = req.params;
    console.log('🔍 Verifying org code:', orgCode);

    // ✅ CRITICAL: Exact match, case-sensitive
    const org = await Organization.findOne({ orgCode: orgCode.trim() });

    if (!org) {
      console.log('❌ Organization not found');
      return res.status(404).json({
        success: false,
        message: 'Organization code not found'
      });
    }

    console.log('✅ Organization found:', org.orgName);

    res.json({
      success: true,
      orgId: org.orgId,
      orgName: org.orgName,
      orgCode: org.orgCode,
      orgType: org.orgType
    });

  } catch (error) {
    console.error('❌ Verify org code error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// Add this new endpoint
exports.getMembersCSV = async (req, res) => {
  try {
    const { orgId } = req.params;
    
    console.log('📥 CSV request for:', orgId);
    
    const org = await Organization.findOne({ orgId });
    if (!org) {
      return res.status(404).json({ 
        success: false, 
        message: 'Organization not found' 
      });
    }

    if (!org.hasCSVUploaded || !org.membersCSVUrl) {
      return res.status(404).json({ 
        success: false, 
        message: 'No CSV uploaded yet' 
      });
    }

    // Parse CSV from S3 or database
    const csvUrl = org.membersCSVUrl;
    const axios = require('axios');
    const csvResponse = await axios.get(csvUrl);
    const csvContent = csvResponse.data;

    // Parse CSV
    const lines = csvContent.split('\n').filter(line => line.trim());
    const dataLines = lines.slice(1); // Skip header

    const members = dataLines.map(line => {
      const parts = line.split(',').map(p => p.trim());
      return {
        unique_id: parts[0],
        name: parts[1],
        role: parts[2],
        department: parts[3],
        branch: parts[4] || null,
        year: parts[5] ? parseInt(parts[5]) : null,
        semester: parts[6] ? parseInt(parts[6]) : null,
        section: parts[7] || null,
        phone: parts[8],
        email: parts[9]
      };
    });

    console.log(`✅ Returning ${members.length} members`);

    res.json({
      success: true,
      members: members,
      org: {
        orgId: org.orgId,
        orgName: org.orgName,
        orgCode: org.orgCode
      }
    });
  } catch (error) {
    console.error('❌ Get CSV error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};