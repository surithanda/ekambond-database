# MySQL Database Error Codes Documentation

This document provides a comprehensive list of all error codes used in the stored procedures of the MySQL database. The error codes are organized by table/procedure group and include a brief description of each error.

## Error Code Format

All custom error codes follow the format:
- SQLSTATE '45000' (Custom error)
- Numeric error codes in the range 50000-69999 are grouped by table/module
- Some modules use a different format with a prefix (e.g., 45001_MISSING_EMAIL)

## Error Codes by Table

### Profile Personal Create (46000-46999)
- `46001_INVALID_ACCOUNTID`: Invalid accountid. It must be a positive integer.
- `46002_MISSING_FIRST_NAME`: First name cannot be empty.
- `46003_MISSING_LAST_NAME`: Last name cannot be empty.
- `46004_INVALID_GENDER`: Invalid gender. Please provide a valid gender (1 for Male, 2 for Female).
- `46005_MISSING_BIRTH_DATE`: Date of birth is required.
- `46006_DUPLICATE_PROFILE`: Profile with the same first name, last name, and date of birth already exists.
- `46007_DUPLICATE_EMAIL`: Profile with the same email already exists.
- `46008_DUPLICATE_PHONE`: Profile with the same mobile phone already exists.
- `46009_INVALID_AGE`: Age should be between 21 and 85.
- `46010_INVALID_ACCOUNT`: Invalid Account ID. The account does not exist.
- `46011_INVALID_MOBILE`: Invalid mobile phone number. It should contain at least 10 digits.
- `46012_INVALID_HOME_PHONE`: Invalid home phone number. It should contain at least 10 digits.
- `46013_INVALID_EMERGENCY_PHONE`: Invalid emergency phone number. It should contain at least 10 digits.
- `46014_INVALID_EMAIL`: Invalid email format.
- `46015_INVALID_HEIGHT`: Invalid height. Height must be greater than 0.
- `46016_INVALID_WEIGHT`: Invalid weight. Weight must be greater than 0.
- `46017_ACCOUNT_IS_NOT_ACTIVE`: This account is not active. Please contact administrator to enable your account.

### Profile Personal (50000-50999)
- `50001`: Invalid profile_id. It must be a positive integer.
- `50002`: Profile does not exist.
- `50003`: Invalid account_id. It must be a positive integer.
- `50004`: Account does not exist.
- `50005`: First name is required.
- `50006`: Last name is required.
- `50007`: Invalid gender value.
- `50008`: Date of birth is required.
- `50009`: Date of birth cannot be in the future.
- `50010`: Profile with this account_id already exists.

### Profile Address (51000-51999)
- `51001`: Invalid profile_id. It must be a positive integer.
- `51002`: Profile does not exist.
- `51003`: Address line 1 is required.
- `51004`: City is required.
- `51005`: State/Province is required.
- `51006`: Country is required.
- `51007`: Postal code is required.
- `51008`: Address type is required.
- `51009`: Invalid address type.
- `51010`: Address ID not found.
- `51011`: Invalid address ID. It must be a positive integer.

### Profile Contact (52000-52999)
- `52001`: Invalid profile_id. It must be a positive integer.
- `52002`: Profile does not exist.
- `52003`: Contact type is required.
- `52004`: Invalid contact type.
- `52005`: Contact value is required.
- `52006`: Contact ID not found.
- `52007`: Invalid contact ID. It must be a positive integer.

### Account Login (45000-45999)
- `45001_MISSING_EMAIL`: Email is required.
- `45002_MISSING_PASSWORD`: Password is required.
- `45003_MISSING_FIRST_NAME`: First name is required.
- `45004_MISSING_LAST_NAME`: Last name is required.
- `45005_DUPLICATE_EMAIL`: Email already exists.
- `45006_DUPLICATE_PHONE`: Primary phone number already exists.
- `45007_INVALID_BIRTH_DATE`: Birth date cannot be in the future.
- `45008_UNDERAGE`: User must be at least 20 years old.
- `45015_EMAIL_DOES_NOT_EXIST`: Email doesn't exist.

### Profile Education (53000-53999)
- `53001`: Invalid profile_id. It must be a positive integer.
- `53002`: Profile does not exist.
- `53003`: Institution name is required.
- `53004`: Degree is required.
- `53005`: Field of study is required.
- `53006`: Start date is required.
- `53007`: Start date cannot be in the future.
- `53008`: End date cannot be earlier than start date.
- `53009`: Education ID not found.
- `53010`: Invalid education ID. It must be a positive integer.

### Profile Search Preference (57000-57999)
- `57001`: Invalid profile_id. It must be a positive integer.
- `57002`: Profile does not exist.
- `57003`: Min age is required.
- `57004`: Max age is required.
- `57005`: Min age cannot be greater than max age.
- `57006`: Min height is required.
- `57007`: Max height is required.
- `57008`: Min height cannot be greater than max height.
- `57009`: Search preference not found for the profile.
- `57010`: Invalid search preference ID.
- `57011`: Search preference does not exist.
- `57012`: Min age is required and must be valid.
- `57013`: Max age is required and must be valid.
- `57014`: Min height is required and must be valid.
- `57015`: Max height is required and must be valid.
- `57016`: Min height cannot be greater than max height.
- `57017`: Invalid search preference ID. It must be a positive integer.
- `57018`: Search preference with this ID does not exist.

### Profile Views (59000-59999)
- `59001`: Invalid profile_id. It must be a positive integer.
- `59002`: Profile does not exist.
- `59003`: Viewed profile ID is required.
- `59004`: Viewed profile does not exist.
- `59005`: Cannot view your own profile.
- `59006`: View record not found.
- `59007`: Invalid profile_id for viewed by me query.
- `59008`: Invalid profile_id for viewed me query.
- `59009`: Viewed profile ID must be valid if provided.
- `59010`: View status must be valid if provided.
- `59011`: View date must be valid if provided.
- `59012`: View record with specified ID does not exist.
- `59013`: Invalid view ID. It must be a positive integer.
- `59014`: View record with this ID does not exist.

### Registered Partner (48000-48999)
- `48001`: Business name is required.
- `48002`: Alias is required.
- `48003`: Primary phone is required.
- `48004`: Primary phone country code is required.
- `48005`: Address line 1 is required.
- `48006`: State is required and must be valid.
- `48007`: Country is required and must be valid.
- `48008`: ZIP code is required.
- `48009`: Business registration number is required.
- `48010`: Business ITIN is required.
- `48011`: Business description is required.
- `48012`: Primary contact first name is required.
- `48013`: Primary contact last name is required.
- `48014`: Business website is required.

### Profile Employment (54000-54999)
- `54001`: Invalid profile_id. It must be a positive integer.
- `54002`: Profile does not exist.
- `54003`: Employer name is required.
- `54004`: Position is required.
- `54005`: Start date is required.
- `54006`: Start date cannot be in the future.
- `54007`: End date cannot be earlier than start date.
- `54008`: Employment ID not found.
- `54009`: Invalid employment ID. It must be a positive integer.

### Profile Property (55000-55999)
- `55001`: Invalid profile_id. It must be a positive integer.
- `55002`: Profile does not exist.
- `55003`: Property type is required.
- `55004`: Property value is required.
- `55005`: Property ID not found.
- `55006`: Invalid property ID. It must be a positive integer.

### Profile Saved For Later (56000-56999)
- `56001`: Invalid profile_id. It must be a positive integer.
- `56002`: Profile does not exist.
- `56003`: Saved profile ID is required and must be valid.
- `56004`: Saved profile does not exist.
- `56005`: A profile cannot save itself.
- `56006`: This profile has already been saved.
- `56007`: Invalid saved record ID. It must be a positive integer.
- `56008`: Saved record does not exist.

### Profile Search Preference (57000-57999)
- `57001`: Invalid profile_id. It must be a positive integer.
- `57002`: Profile does not exist.
- `57003`: Minimum age must be at least 18.
- `57004`: Maximum age must be greater than minimum age.
- `57005`: Invalid gender preference.
- `57006`: Search preference already exists for this profile.
- `57007`: Invalid search preference ID. It must be a positive integer.
- `57008`: Search preference record does not exist.

### Profile Favorites (58000-58999)
- `58001`: Invalid profile_id. It must be a positive integer.
- `58002`: Profile does not exist.
- `58003`: Favorite profile ID is required and must be valid.
- `58004`: Favorite profile does not exist.
- `58005`: A profile cannot favorite itself.
- `58006`: This profile has already been favorited.
- `58007`: Invalid favorite ID. It must be a positive integer.
- `58008`: Favorite record does not exist.
- `58009`: Invalid favorite status. It must be 0 or 1.
- `58010`: Favorite status is required.
- `58011`: Favorite status is already set to this value.
- `58012`: Invalid favorite ID. It must be a positive integer.
- `58013`: Favorite record does not exist.
- `58014`: Invalid id. It must be a positive integer.
- `58015`: Favorite record with specified ID does not exist.

### Profile Views (59000-59999)
- `59001`: Invalid profile_id. It must be a positive integer.
- `59002`: Profile does not exist.
- `59003`: Viewed profile ID is required and must be valid.
- `59004`: Viewed profile does not exist.
- `59005`: A profile is viewing itself.
- `59006`: At least one of profile_id, viewed_profile_id, or id must be provided.
- `59007`: Invalid id. It must be a positive integer.
- `59008`: View record with specified ID does not exist.
- `59009`: Viewed profile ID must be valid if provided.
- `59010`: Viewed profile does not exist.
- `59011`: A profile is viewing itself.
- `59012`: View date cannot be in the future.
- `59013`: Invalid id. It must be a positive integer.
- `59014`: View record with specified ID does not exist.

### Profile Contacted (60000-60999)
- `60001`: Invalid profile_id. It must be a positive integer.
- `60002`: Profile does not exist.
- `60003`: Contacted profile ID is required and must be valid.
- `60004`: Contacted profile does not exist.
- `60005`: A profile cannot contact itself.
- `60006`: Contact method is required.
- `60007`: At least one of profile_id, contacted_profile_id, or id must be provided.
- `60008`: Invalid id. It must be a positive integer.
- `60009`: Contact record with specified ID does not exist.
- `60010`: Contacted profile ID must be valid if provided.
- `60011`: Contacted profile does not exist.
- `60012`: A profile cannot contact itself.
- `60013`: Contact method cannot be empty if provided.
- `60014`: Contact date cannot be in the future.
- `60015`: Invalid id. It must be a positive integer.
- `60016`: Contact record with specified ID does not exist.

### Profile Family Reference (61000-61999)
- `61001`: Invalid profile_id. It must be a positive integer.
- `61002`: Profile does not exist.
- `61003`: Name is required.
- `61004`: Relationship is required.
- `61005`: Contact information is required.
- `61006`: Family reference ID not found.
- `61007`: Invalid family reference ID. It must be a positive integer.

### Profile Hobby Interest (62000-62999)
- `62001`: Invalid profile_id. It must be a positive integer.
- `62002`: Profile does not exist.
- `62003`: Hobby/interest name is required.
- `62004`: Hobby/interest ID not found.
- `62005`: Invalid hobby/interest ID. It must be a positive integer.

### Profile Lifestyle (53000-53999)
- `53001`: Invalid profile_id. It must be a positive integer.
- `53002`: Profile does not exist.
- `53004`: Lifestyle information already exists for this profile.
- `53005`: Either profile_id or id must be provided.
- `53006`: Invalid profile_lifestyle_id. It must be a positive integer.
- `53007`: Lifestyle record with specified ID does not exist.

### Profile Photo (64000-64999)
- `64001`: Invalid profile_id. It must be a positive integer.
- `64002`: Profile does not exist.
- `64003`: Photo URL is required.
- `64004`: Photo type is required.
- `64005`: Invalid photo type.
- `64006`: Photo ID not found.
- `64007`: Invalid photo ID. It must be a positive integer.
- `64008`: Cannot set more than one primary photo.

## General Guidelines for Error Handling

1. All procedures use SQLSTATE '45000' for custom errors
2. Each table/procedure group has a dedicated range of error codes
3. Error messages are descriptive and user-friendly
4. All errors are logged to the activity_log table
5. Error handling includes both SQL exceptions and custom validation errors
