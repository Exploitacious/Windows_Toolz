# Datto RMM Script Templates

This repository contains PowerShell script templates for use with Datto RMM.
These templates provide a foundation for creating Monitoring and Remediation scripts that integrate seamlessly with Datto RMM.

## Templates

### 1. DRMM_MonitoringTemplate.ps1

This template is designed for creating monitoring scripts in Datto RMM.

Key features:

- Configurable script name and type
- Functions for natively writing diagnostics and alerts to Datto RMM
- Unique script identifier generation (Script UID)
- Customizable main script logic section
- Ability to write to a UDF in Datto RMM (define variable in Datto RMM GUI)
- Proper exit handling for Datto RMM

### 2. DRMM_RemediationTemplate.ps1

This template is designed for creating remediation scripts in Datto RMM.

Key features:

- Configurable script name and type
- Functions for writing diagnostics to Datto RMM
- Unique script identifier generation (Script UID)
- Customizable main script logic section
- Ability to write to a UDF in Datto RMM (define variable in Datto RMM GUI)
- Optional API result submission (Defined in DattoRMM - Used for Umbrella API to Autotask Ticket Billing Integration)
- Proper exit handling for Datto RMM

## Usage

1. Choose the appropriate template based on your needs (monitoring or remediation).
2. Copy the template and rename it according to your script's purpose.
3. Modify the `$scriptName` and `$scriptType` variables at the top of the script.
4. Implement your script logic in the designated section (between the "Start of Script" and "End of Script" comments).
5. Test your script thoroughly before deploying in Datto RMM.
6. Add Script to Datto RMM by using the "Add Component" feature and selecting the right script type.
7. Add UDF writing and API submission variables as needed

## Important Notes

- These scripts rely on environment variables set by Datto RMM. Do not modify the `$env:` variable references unless you're certain about the changes.
- The monitoring script uses Exit 0 for "No Alert" and Exit 1 for "Alert" status in Datto RMM.

## Customization

Feel free to modify these templates to better suit your specific needs. However, be cautious when changing core functionality that interfaces with Datto RMM, such as the diagnostic writing functions or exit handling.

## Support

For issues related to Datto RMM integration or platform-specific questions, please refer to Datto RMM documentation or contact their support.

For template-specific questions or improvements, please open an issue in this repository.

- Datto RMM Scripting Documentation:
  https://rmm.datto.com/help/en/Content/4WEBPORTAL/Components/Scripting.htm
