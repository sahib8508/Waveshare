const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// Registration Flow
router.post('/register', authController.registerOrganization);
router.post('/verify-email', authController.verifyEmailOTP);
router.post('/resend-email-otp', authController.resendEmailOTP);
router.post('/verify-phone', authController.verifyPhoneOTP);
router.post('/resend-phone-otp', authController.resendPhoneOTP);
router.post('/upload-document', authController.uploadDocument);
router.post('/skip-document', authController.skipDocument);

// CSV Upload
router.post('/upload-csv', authController.uploadCSV);

// Login
router.post('/admin-login', authController.adminLogin);

// Test Routes
router.get('/test-s3', authController.testS3);
router.get('/test-csv-upload', authController.testCSVUpload);
router.get('/get-members-csv/:orgId', authController.getMembersCSV);
router.get('/verify-org-code/:orgCode', authController.verifyOrgCode);
module.exports = router;