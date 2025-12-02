// models/Organization.js - REPLACE ENTIRE FILE
const mongoose = require('mongoose');

const organizationSchema = new mongoose.Schema({
  // Basic Info
  orgId: { type: String, required: true, unique: true },
  orgName: { type: String, required: true },
  orgType: { type: String, required: true },
  orgCode: { type: String, required: true, unique: true },
  emailDomain: { type: String, required: true },
  
  // Admin Info
  adminId: { type: String, required: true },
  adminEmail: { type: String, required: true, unique: true },
  adminName: { type: String, required: true },
  adminPhone: { type: String, required: true },
  adminPassword: { type: String, required: false },
  
  // Verification
  verificationStatus: { type: String, default: 'pending' },
  emailOTP: { code: String, expiresAt: Date },
  phoneOTP: { code: String, expiresAt: Date },
  documentUrl: String,
  documentType: String,
  
  // ✅ NEW: Single CSV with Hierarchy
  membersCSVUrl: String,
  csvUploadedAt: Date,
  hasCSVUploaded: { type: Boolean, default: false },
  
  // ✅ NEW: Parsed Hierarchy Data
  hierarchy: {
    totalMembers: { type: Number, default: 0 },
    totalStudents: { type: Number, default: 0 },
    totalFaculty: { type: Number, default: 0 },
    totalStaff: { type: Number, default: 0 },
    
    departments: [{
      name: String,
      totalMembers: Number,
      branches: [{
        name: String,
        totalMembers: Number,
        years: [{
          year: Number,
          semesters: [{
            semester: Number,
            sections: [{
              section: String,
              totalMembers: Number
            }]
          }]
        }]
      }]
    }]
  },
  
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Organization', organizationSchema);