# Workstation cluster access

- Installed checksum-verified standalone kubectl v1.36.4 for Windows and copied the working remote kubeconfig over SSH with restricted file permissions. No credential content was printed or committed.
- Native Windows TLS validation failed. Read-only certificate comparison established that local HTTPS inspection presented a replacement certificate; the same config worked on yeti and WSL saw the original certificate.
- Installed checksum-verified Linux kubectl v1.36.4 in the WSL user's local bin directory, with a mode-0600 private kubeconfig.
- Verified both nodes Ready, expected system pods Running/Completed, and PowerShell-to-WSL administration. No cluster resources or antivirus settings changed.
- Native Windows client remains installed but was not added to PATH. WSL administration is the working supported workflow for this setup.
