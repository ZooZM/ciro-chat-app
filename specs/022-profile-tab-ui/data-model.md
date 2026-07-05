# Data Model: Profile Tab UI

All data entities for this feature are for presentation purposes only and will be mocked.

### Entities

1. **`UserProfile`**
   - `name`: String
   - `bio`: String
   - `ciroId`: String
   - `avatarUrl`: String (or placeholder asset)
   - `completionPercentage`: int

2. **`WalletInfo`**
   - `totalBalance`: String (formatted)
   - `currentBalance`: String (formatted)
   - `currency`: String

3. **`ThemePreview`**
   - `id`: String
   - `thumbnailPath`: String

4. **`ChatColorOption`**
   - `id`: String
   - `color`: Color

5. **`BackgroundOption`**
   - `id`: String
   - `imagePath`: String
   - `isCustomAdd`: bool
