import re
import os
import glob

base_path = r'c:\Users\naidu\OneDrive\Desktop\Local-Vyapari\lib\domain\providers'
files = glob.glob(os.path.join(base_path, '*_provider.dart'))

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find async methods that set isLoading: true but don't have finally block
    # We'll use regex to inject finally { state = state.copyWith(isLoading: false); }
    # This is a bit tricky, but we can do a naive substitution where we look for catch blocks
    
    # Just a simple replacement for methods that return some type and have catch(e) { ... return ...; }
    # Since dart catch blocks end with "}", we can replace "return false;\n    }" or "return null;\n    }" 
    # with "return ...;\n    }\n    finally {\n      state = state.copyWith(isLoading: false);\n    }"
    
    # Simple heuristic
    content = re.sub(r'(catch \([^\)]+\)\s*\{.*?return [^;]+;\s*\})', r'\1\n    finally {\n      state = state.copyWith(isLoading: false);\n    }', content, flags=re.DOTALL)
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
