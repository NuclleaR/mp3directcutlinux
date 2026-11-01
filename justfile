# Debug build of the Linux app, with hot reload (r) and hot restart (R) in the terminal.
run:
    mise exec -- flutter run -d linux

# Removes build/, .dart_tool/ (test-built native libs too) and linux/flutter/ephemeral/.
clean:
    mise exec -- flutter clean
