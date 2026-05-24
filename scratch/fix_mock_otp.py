import re

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Replace `final otp = await ref.read(authProvider.notifier).requestOtp(phone);`
    # with `final success = await ...`
    content = re.sub(r'final otp = await (.+?)\.requestOtp\((.*?)\);', r'final success = await \1.requestOtp(\2);', content)
    content = re.sub(r'final otp = await (.+?)\.requestBindPhoneOtp\((.*?)\);', r'final success = await \1.requestBindPhoneOtp(\2);', content)
    
    # 2. Replace `if (otp != null)` with `if (success)`
    content = content.replace('if (otp != null) {', 'if (success) {')
    
    # 3. Remove `_mockOtp = otp;` or `String? mockOtp = otp;`
    content = re.sub(r'String\?\s+mockOtp\s*=\s*otp;', '', content)
    content = re.sub(r'_mockOtp\s*=\s*otp;', '', content)
    
    # 4. Remove `String? _mockOtp;`
    content = re.sub(r'String\?\s+_mockOtp;', '', content)

    # 5. Remove `mockOtp` UI blocks (for testing/development texts)
    # E.g. "For testing/development, use verification code: $otp" -> "Please check your messages."
    content = re.sub(r'For testing/development, use verification code: \$otp', 'Please check your SMS messages.', content)

    # UI blocks
    content = re.sub(r'if \(_mockOtp != null\) \.\.\.\[.*?\]\,', '', content, flags=re.DOTALL)
    content = re.sub(r'if \(mockOtp != null\) \.\.\.\[.*?\]\,', '', content, flags=re.DOTALL)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file(r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\ui\screens\shop\setup_shop_screen.dart')
fix_file(r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\ui\screens\profile\profile_screen.dart')
