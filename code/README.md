# Apnagram.in 

## Project Description
Apnagram.in is a unique and impactful portal designed to empower rural communities, revitalize local marketplaces, and facilitate meaningful engagement among citizens and their leaders. This project aims to cater to the specific needs of rural/town populations by providing them with a platform for trade, communication, and accountability.

---

## App Overview
Key functionalities include:
- Local news updates
- A micro-marketplace
- Direct communication with local elected representatives through complaint forms(MPs, etc.)
- Quarterly analysis of the leaders

### Main Components
#### 1. News Feed
- Displays micro-localized news updates at the village level and neighboring areas.
- Uses aggregators to pull news based on relevant keywords and the user’s pin code.
- The first feed visible to users upon opening the app.

#### 2. Micro-Marketplace
- Enables farmers to buy and sell goods locally.
- Functions similarly to OLX or eBay, filtering customers/sellers based on pin code.
- Clicking "Contact Seller" initiates a chat with a reference to the product.

#### 3. Ask your Neta Section
- Provides a platform for villagers to raise queries to their MPs and track responses.
- Users must verify their phone number via OTP before submitting a question.
- Questions are forwarded to respective MPs, and quarterly reports showcase answered/unanswered queries.
- Free users can only ask questions to the MP of their district.
- MPs' emails need to be collected and stored in JSON format.

#### 4. Additional Features
- **Phone-number-based signup**: Users must submit their mobile number, pin code, and village.
- **Image Downsizing**: Images will be downscaled to optimize storage and performance.

---

## User Tiers
1. **Free Users**: Limited to a marketplace within their pin code. Can only ask/view questions about MPs within their constituency.
2. **Premium Users**: Can search for any pin code in the marketplace and look up MPs based on constituency or name. Additional search functionalities.
3. **Admin Users**: Can generate composite reports on app usage. They will have a separate Flask-based interface for analytics instead of an app profile.

---

## Development Updates
### Flagging Posts
- In early development, posts reported beyond a certain threshold will be removed.
- Future improvements include detecting hate speech/inappropriate content before removal.

### Item Purchase Flow
- No cart functionality.
- Buyers directly contact sellers through the "Contact Seller" feature.
- The app does not handle transactions or remove sold items from listings.
- Sellers must manually take down their posts after selling items.

### Profile Management
- Users can modify profile details via an edit icon.
- Phone number changes require OTP verification.
- Pin code changes are limited to prevent abuse.

---

This README provides an overview of Apnagram.in, detailing its objectives, features, development progress, and future plans. More updates will be added as development continues.

