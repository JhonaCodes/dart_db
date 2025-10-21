# Troubleshooting Guide for dart_db

## Library Loading Issues on Linux

If you encounter an error like this:

```
ERROR: Unix library loading
  --> package:your_app/...
   |
   = error: DbError(ffi: Failed to load native library for linux, context: Unix library loading, cause: Attempted paths: ...)
```

This means the native library `liboffline_first_core.so` cannot be found.

### 🔍 First Step: Run the Diagnostic Tool

Before trying manual solutions, use our built-in diagnostic tool to see exactly what's happening:

```dart
import 'package:dart_db/dart_db.dart';

void main() {
  LibraryLoader.printDebugInfo();
}
```

Or run the included example:

```bash
dart run package:dart_db/example/debug.dart
```

This will show you:
- Where dart_db is searching for the library
- Whether the library file exists
- Your system configuration
- Specific recommendations for your situation

### 💡 Solutions

### Solution 1: Automatic Package Detection (Recommended)

As of version 0.2.0+, dart_db automatically detects the package location using `package_config.json`. This should work automatically in most cases.

**If this doesn't work**, try running:
```bash
cd your_project
dart pub get
```

This will regenerate the `.dart_tool/package_config.json` file with correct package paths.

### Solution 2: System Installation (Most Reliable)

Install the library to a system directory where the dynamic linker can find it:

#### Option A: Using the install script (requires sudo)

```bash
# Navigate to the dart_db package directory
cd ~/.pub-cache/git/dart_db-<hash>/

# Or if using a local path dependency
cd path/to/dart_db/

# Run the installer
sudo scripts/install_linux.sh
```

#### Option B: Manual installation

```bash
# Find the library in your .pub-cache
find ~/.pub-cache -name "liboffline_first_core.so"

# Copy to system directory (replace <path> with the actual path)
sudo cp <path>/liboffline_first_core.so /usr/local/lib/

# Update dynamic linker cache
sudo ldconfig
```

### Solution 3: Copy to Application Directory

Copy the library to your application's directory:

```bash
# Find the library
find ~/.pub-cache -name "liboffline_first_core.so"

# Copy to your project directory
cp <path>/liboffline_first_core.so your_project/

# Or create a lib directory
mkdir -p your_project/lib
cp <path>/liboffline_first_core.so your_project/lib/
```

### Solution 4: Using LD_LIBRARY_PATH

Set the `LD_LIBRARY_PATH` environment variable:

```bash
# Find the library directory
find ~/.pub-cache -name "liboffline_first_core.so"

# Set LD_LIBRARY_PATH (replace <directory> with the directory containing the .so file)
export LD_LIBRARY_PATH=<directory>:$LD_LIBRARY_PATH

# Run your Dart application
dart run your_app.dart
```

Or add it to your `.bashrc` or `.zshrc` for persistence:

```bash
echo 'export LD_LIBRARY_PATH=/path/to/library/directory:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### Solution 5: Docker/Container Environments

If running in Docker or containers, ensure the library is copied during the build:

```dockerfile
# In your Dockerfile
FROM dart:stable

# Copy your application
COPY . /app
WORKDIR /app

# Get dependencies
RUN dart pub get

# Find and copy the library to a system path
RUN find /root/.pub-cache -name "liboffline_first_core.so" -exec cp {} /usr/local/lib/ \;
RUN ldconfig

# Run your app
CMD ["dart", "run", "bin/your_app.dart"]
```

### Verifying the Installation

After trying any solution, verify the library can be found:

```bash
# Check if the library is in the system path
ldconfig -p | grep liboffline_first_core

# Or check if the file exists in a standard location
ls -la /usr/local/lib/liboffline_first_core.so
```

### Debugging

To see detailed information about where dart_db is searching for the library:

```dart
import 'package:dart_db/dart_db.dart';
import 'package:dart_db/src/core/library_loader.dart';

void main() {
  // Print environment information
  final env = LibraryLoader.getEnvironmentInfo();
  print('Environment Information:');
  env.forEach((key, value) => print('  $key: $value'));

  // Try to open a database (will show detailed error)
  final result = DB.open('test_db');
  result.when(
    ok: (db) {
      print('✓ Database opened successfully!');
      db.close();
    },
    err: (error) {
      print('✗ Error opening database:');
      print('  $error');
    },
  );
}
```

### Platform-Specific Notes

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y libc6
```

#### Fedora/RHEL/CentOS

```bash
sudo yum install -y glibc
```

#### Alpine Linux (Docker)

```bash
apk add --no-cache libc6-compat
```

### Still Having Issues?

If none of these solutions work:

1. **Check the library exists**: Verify that `liboffline_first_core.so` is present in the dart_db package:
   ```bash
   find ~/.pub-cache -path "*/dart_db*/binary/linux/liboffline_first_core.so"
   ```

2. **Check file permissions**: Ensure the library has execute permissions:
   ```bash
   chmod +x path/to/liboffline_first_core.so
   ```

3. **Check architecture**: Ensure the library matches your system architecture:
   ```bash
   file path/to/liboffline_first_core.so
   uname -m
   ```

4. **Open an issue**: If all else fails, please open an issue on GitHub with:
   - Your operating system and version
   - Output of `dart --version`
   - Output of `uname -a`
   - The full error message
   - Output of the debugging script above

## Other Common Issues

### Permission Denied

If you get a "permission denied" error:

```bash
chmod +x path/to/liboffline_first_core.so
```

### Wrong Architecture

If you get an "invalid ELF header" or "wrong architecture" error, the library doesn't match your system architecture. Please open an issue on GitHub.

### Memory Errors

If you encounter segmentation faults or memory errors:

1. Ensure you're closing databases properly:
   ```dart
   db.close();
   ```

2. Don't use a database after closing it
3. Ensure data sizes don't exceed limits (16MB per value)

## Getting Help

- **GitHub Issues**: https://github.com/jhonacodes/dart_db/issues
- **Email**: info@jhonacode.com

When reporting issues, please include:
- Operating system and version
- Dart SDK version
- Full error message
- Output of `LibraryLoader.getEnvironmentInfo()`
