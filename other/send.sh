#!/bin/bash
# https://aadinternals.com/osint/

# ==============================================================================
# Swaks Unauthenticated Email Test Script
#
# Description:
# This script attempts to send an email WITHOUT authentication to test if the
# SMTP server is configured as an open relay or has a misconfigured trust
# relationship that could allow for spoofing. It connects to the specified
# SMTP server and tries to send an email from a forged address.
#
# Purpose:
# This is for security testing to replicate a potential finding and verify
# that the SMTP server correctly rejects unauthenticated/spoofed mail.
# If this email is successfully sent, it indicates a server misconfiguration.
#
# Prerequisites:
# 1. swaks must be installed on your system.
#    - On Debian/Ubuntu: sudo apt-get install swaks
#    - On CentOS/RHEL: sudo yum install swaks
# ==============================================================================

# --- Configuration Variables ---

# SMTP Server Details
# Port 25 is the standard for unauthenticated SMTP.
# IMPORTANT: The Red Team may have used a specific IP address of an internal
# relay or gateway, not the public MX record. You may need to change this.
SMTP_SERVER="TARGET-mail-onmicrosoft-com.mail.protection.outlook.com"
SMTP_PORT="25"

# Spoofed HELO Name
# This is the hostname our script will use to introduce itself to the server.
# A common technique is to make this look like a trusted internal mail server.
HELO_NAME="TARGET.onmicrosoft.com"

# Email Details
# We use a "spoofed" sender address to test the vulnerability.
# This should be an address within the target domain.
SENDER_EMAIL="sender"
RECIPIENT_EMAIL="redipient" # Change to a valid recipient you can check
SUBJECT="**SECURITY TEST** Unauthenticated Email Check (Spoofed HELO)"
BODY_CONTENT="This is a test email sent without authentication.

It was sent by presenting a spoofed HELO name of '$HELO_NAME'.

If you have received this message, the SMTP server at $SMTP_SERVER may be configured to trust clients based on their HELO name, which is a security risk.

This test was initiated on: $(date)"

# --- Script Execution ---

echo "Preparing to send an unauthenticated test email..."
echo " >> Target Server: $SMTP_SERVER:$SMTP_PORT"
echo " >> From (Spoofed): $SENDER_EMAIL"
echo " >> To: $RECIPIENT_EMAIL"
echo " >> HELO Name (Spoofed): $HELO_NAME"

# The swaks command for unauthenticated sending.
# --helo: Sets the name used in the SMTP HELO/EHLO command. This is key for
#         simulating a trusted source.
swaks \
    --tls \
    --to "$RECIPIENT_EMAIL" \
    --from "$SENDER_EMAIL" \
    --server "$SMTP_SERVER" \
    --port "$SMTP_PORT" \
    --helo "$HELO_NAME" \
    --header "Subject: $SUBJECT" \
    --header "X-Mailer: Swaks-Security-Test/1.0" \
    --header "X-Priority: 1 (Highest)" \
    --body "$BODY_CONTENT"

# Check the exit code of the swaks command
if [ $? -eq 0 ]; then
    echo "----------------------------------------------------------------"
    echo "SUCCESS: The test email was accepted by the server!"
    echo "WARNING: This indicates the server may be an open relay or is"
    echo "         improperly trusting the spoofed HELO $HELO_NAME."
    echo "code:    $? "
    echo "----------------------------------------------------------------"
else
    echo "----------------------------------------------------------------"
    echo "FAILURE: The server rejected the email as expected."
    echo "INFO:     This is the desired outcome for a secure configuration."
    echo "code:    $? "
    echo "----------------------------------------------------------------"
fi

echo "Script finished."
