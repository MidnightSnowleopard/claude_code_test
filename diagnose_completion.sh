#!/bin/bash
# Diagnostic script for file_organizer completion issues
# Run this on your FreeBSD system to identify the problem

echo "=== Bash Completion Diagnostics ==="
echo ""

# 1. Check bash version
echo "1. Bash version:"
bash --version | head -1
echo ""

# 2. Check if bash supports associative arrays (requires bash 4.0+)
echo "2. Testing associative array support:"
if declare -A test_array 2>/dev/null; then
    test_array["key"]="value"
    if [ "${test_array[key]}" = "value" ]; then
        echo "   ✓ Associative arrays supported"
    else
        echo "   ✗ Associative arrays not working properly"
    fi
else
    echo "   ✗ Associative arrays NOT supported (need bash 4.0+)"
fi
echo ""

# 3. Check if completion function is defined
echo "3. Checking if completion function is defined:"
if declare -f _file_organizer_complete >/dev/null 2>&1; then
    echo "   ✓ Function _file_organizer_complete is defined"
else
    echo "   ✗ Function _file_organizer_complete NOT defined"
    echo "   → Source the completion file: source /path/to/file_organizer_completion.bash"
fi
echo ""

# 4. Check if complete command is registered
echo "4. Checking complete registration:"
if complete -p file_organizer.sh 2>/dev/null; then
    echo "   ✓ Completion registered for file_organizer.sh"
else
    echo "   ✗ Completion NOT registered for file_organizer.sh"
fi
echo ""

# 5. Check bash-completion package (FreeBSD specific)
echo "5. Checking bash-completion installation:"
if [ -f /usr/local/share/bash-completion/bash_completion ]; then
    echo "   ✓ bash-completion appears to be installed"
    if grep -q "bash_completion" ~/.bashrc 2>/dev/null; then
        echo "   ✓ bash-completion is sourced in ~/.bashrc"
    else
        echo "   ✗ bash-completion NOT sourced in ~/.bashrc"
        echo "   → Add to ~/.bashrc:"
        echo "      [[ -r /usr/local/share/bash-completion/bash_completion ]] && . /usr/local/share/bash-completion/bash_completion"
    fi
else
    echo "   ✗ bash-completion NOT installed"
    echo "   → Install with: pkg install bash-completion"
fi
echo ""

# 6. Test basic completion
echo "6. Testing basic bash completion:"
if complete -p cd >/dev/null 2>&1; then
    echo "   ✓ Basic bash completion is working"
else
    echo "   ✗ Basic bash completion not working"
    echo "   → bash-completion framework may not be loaded"
fi
echo ""

# 7. Check for errors when sourcing
echo "7. Testing completion file for syntax errors:"
if bash -n /home/user/claude_code_test/file_organizer_completion.bash 2>&1; then
    echo "   ✓ No syntax errors found"
else
    echo "   ✗ Syntax errors detected in completion file"
fi
echo ""

echo "=== Recommendations ==="
echo ""
echo "If completion still doesn't work, try:"
echo "  1. Ensure bash 4.0+ is installed"
echo "  2. Install bash-completion: pkg install bash-completion"
echo "  3. Add to ~/.bashrc:"
echo "     [[ -r /usr/local/share/bash-completion/bash_completion ]] && . /usr/local/share/bash-completion/bash_completion"
echo "     source /path/to/file_organizer_completion.bash"
echo "  4. Reload: source ~/.bashrc"
echo "  5. Try in a new terminal window"
