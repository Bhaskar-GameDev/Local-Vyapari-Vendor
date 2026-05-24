import os

def patch_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for i, line in enumerate(lines):
        if 'userId: data[\'userId\']' in line:
            lines[i] = "      userId: (data['userId'] ?? '') as String,\n"
        elif "userDisplayName: data['userDisplayName']" in line:
            lines[i] = "      userDisplayName: (data['userDisplayName'] ?? 'Anonymous User') as String,\n"
        elif "productId: data['productId']" in line:
            lines[i] = "      productId: (data['productId'] ?? '') as String,\n"
        elif "shopId: data['shopId']" in line:
            lines[i] = "      shopId: (data['shopId'] ?? '') as String,\n"
        elif "rating: (data['rating']" in line:
            lines[i] = "      rating: ((data['rating'] ?? 0.0) as num).toDouble(),\n"
        elif "comment: data['comment']" in line:
            lines[i] = "      comment: (data['comment'] ?? '') as String,\n"
            
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

patch_file(r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\data\models\product_review.dart')
patch_file(r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\data\models\shop_review.dart')
