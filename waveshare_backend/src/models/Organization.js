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
  verificationStatus: {
    type: String,
    enum: ['pending', 'email_verified', 'document_verified', 'fully_verified'],
    default: 'pending',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  stats: {
    totalMembers: { type: Number, default: 0 },
    totalFilesShared: { type: Number, default: 0 },
    totalDataTransferred: { type: Number, default: 0 },
  },
});

module.exports = mongoose.model('Organization', organizationSchema);