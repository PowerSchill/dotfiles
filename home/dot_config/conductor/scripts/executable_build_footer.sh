#!/bin/zsh

# Preprocessor script to build a timestamp footer
# Tried doing this with some JavaScript insertion and DOM updating, but Marked 2 balked at the rendering.
# In the end I just built it from scratch using a simple shell script as a simple pipeline processor script

# Output the content streamed in
cat <&0

# Append the footer
echo -e "<p> </p>"
echo -e "<div class=\"footer\">"
echo -e -n "<b>Preview Generated:</b> $(date +"%y-%m-%d %H:%M:%S")"
echo -e "</div>"
