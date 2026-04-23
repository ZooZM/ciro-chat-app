# Interface Contract: Auth Remote Data Source

## Endpoints

### 1. Send OTP
- **Method**: POST
- **Path**: `/auth/send-otp`
- **Body**:
  ```json
  { "phoneNumber": "string" }
  ```
- **Response (200)**:
  ```json
  { "success": true, "message": "OTP sent" }
  ```

### 2. Verify OTP
- **Method**: POST
- **Path**: `/auth/verify-otp`
- **Body**:
  ```json
  { "phoneNumber": "string", "code": "string" }
  ```
- **Response (200)**:
  ```json
  {
    "data": {
      "accessToken": "string",
      "refreshToken": "string",
      "user": { "id": "string", "phone": "string" }
    }
  }
  ```
