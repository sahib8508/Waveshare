const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// Registration flow
router.post('/register', authController.registerOrganization);
router.post('/verify-email', authController.verifyEmailOTP);
router.post('/resend-email-otp', authController.resendEmailOTP);
router.post('/verify-phone', authController.verifyPhoneOTP);
router.post('/resend-phone-otp', authController.resendPhoneOTP);
router.post('/upload-document', authController.uploadDocument);
router.post('/skip-document', authController.skipDocument);

// Login
router.post('/login', authController.adminLogin);

module.exports = router;