const mongoose = require('mongoose');

const organizationSchema = new mongoose.Schema({
  orgId: {
    type: String,
    required: true,
    unique: true,
  },
  orgName: {
    type: String,
    required: true,
  },
  orgType: {
    type: String,
    required: true,
    enum: ['Education', 'Mining', 'Healthcare', 'Corporate', 'Other'],
  },
  orgCode: {
    type: String,
    required: true,
    unique: true,
  },
  emailDomain: {
    type: String,
    required: true,
  },
  adminId: {
    type: String,
    required: true,
    unique: true,
  },
  adminEmail: {
    type: String,
    required: true,
  },
  adminName: {
    type: String,
    required: true,
  },
  adminPhone: {
    type: String,
    required: true,
  },
  adminPassword: {
    type: String,
    required: false,
  },
  // OTP Storage
  emailOTP: {
    code: String,
    expiresAt: Date,
  },
  phoneOTP: {
    code: String,
    expiresAt: Date,
  },
  // Verification stages
  verificationStatus: {
    type: String,
    enum: ['pending', 'email_verified', 'phone_verified', 'document_uploaded', 'fully_verified'],
    default: 'pending',
  },
  // Document verification
  documentUrl: {
    type: String,
    required: false,
  },
  documentType: {
    type: String,
    enum: ['Official Letterhead', 'Registration Certificate', 'Accreditation Document'],
    required: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  lastSynced: {
    type: Date,
    default: Date.now,
  },
  stats: {
    totalMembers: { type: Number, default: 0 },
    totalFilesShared: { type: Number, default: 0 },
    totalDataTransferred: { type: Number, default: 0 },
  },
  // Add to your existing Organization schema in models/Organization.js

// Add these fields to your schema:

hasCSVUploaded: {
  type: Boolean,
  default: false,
},

studentsCSVUrl: {
  type: String,
  default: null,
},

teachersCSVUrl: {
  type: String,
  default: null,
},

totalStudents: {
  type: Number,
  default: 0,
},

totalTeachers: {
  type: Number,
  default: 0,
},

csvUploadedAt: {
  type: Date,
  default: null,
},
});

module.exports = mongoose.model('Organization', organizationSchema);