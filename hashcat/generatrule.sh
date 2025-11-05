#!/bin/bash

# This script generates password-cracking rules for appending all
# two-character alphanumeric combinations to a word.
# (e.g., $a$a, $a$b, $a$c ... $9$8, $9$9)

# A string containing all characters to be used.
CHARS='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#!#$%^&*()_+?><":\/;:"'

# Use nested loops to iterate through every possible two-character combination.
for (( i=0; i<${#CHARS}; i++ )); do
  for (( j=0; j<${#CHARS}; j++ )); do
    # Get the character at the current position for each loop.
    char1="${CHARS:$i:1}"
    char2="${CHARS:$j:1}"

    # Print the rule in the correct format for tools like Hashcat or John the Ripper.
    # The backslashes are needed to escape the '$' so it's printed literally.
    echo "\$${char1} \$${char2}"
  done
done