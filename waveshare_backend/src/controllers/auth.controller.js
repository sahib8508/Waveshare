const Organization = require('../models/Organization');
const crypto = require('crypto');

// Generate unique organization code
function generateOrgCode(orgName) {
  const prefix = orgName.substring(0, 3).toUpperCase();
  const randomPart = crypto.randomBytes(3).toString('hex').toUpperCase().substring(0, 5);
  return `WAVE-${prefix}-${randomPart}`;
}

// Generate unique organization ID
function generateOrgId() {
  return `ORG_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

// Generate unique admin ID
function generateAdminId(orgCode) {
  const orgPart = orgCode.split('-')[1];
  return `ADM-${orgPart}-001`;
}

// MAIN REGISTRATION FUNCTION
exports.registerOrganization = async (req, res) => {
  try {
    const { orgName, orgType, emailDomain, adminEmail, adminName, adminPhone } = req.body;

    console.log('📝 Registration request received:', {
      orgName,
      orgType,
      adminEmail,
    });

    // Validate input
    if (!orgName || !orgType || !emailDomain || !adminEmail || !adminName || !adminPhone) {
      console.log('❌ Validation failed: Missing fields');
      return res.status(400).json({
        success: false,
        message: 'All fields are required',
      });
    }

    // Check if organization already exists
    const existingOrg = await Organization.findOne({
      $or: [
        { adminEmail: adminEmail },
        { emailDomain: emailDomain },
      ],
    });

    if (existingOrg) {
      console.log('❌ Organization already exists');
      return res.status(400).json({
        success: false,
        message: 'Organization with this email or domain already exists',
      });
    }

    // Generate unique codes
    const orgId = generateOrgId();
    const orgCode = generateOrgCode(orgName);
    const adminId = generateAdminId(orgCode);

    console.log('🔑 Generated codes:', { orgId, orgCode, adminId });

    // Create new organization
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
      verificationStatus: 'pending',
    });

    // Save to database
    await newOrg.save();

    console.log('✅ Organization saved successfully:', orgCode);

    res.status(201).json({
      success: true,
      message: 'Organization registered successfully',
      orgId: newOrg.orgId,
      orgCode: newOrg.orgCode,
      adminId: adminId,
    });

  } catch (error) {
    console.error('❌ Registration error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Server error during registration',
      error: error.message,
    });
  }
};