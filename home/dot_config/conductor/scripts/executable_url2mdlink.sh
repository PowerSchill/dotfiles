#!/bin/zsh

cat | sed -E 's#(https?://[^ ]+)#\[\1\](\1)#g'
