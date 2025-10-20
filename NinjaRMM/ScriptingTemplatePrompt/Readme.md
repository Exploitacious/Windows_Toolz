# AI-Powered Ninja RMM Script Generator

## 1. Overview

Welcome! This toolkit is designed to help you generate high-quality, standardized PowerShell scripts for Ninja RMM using a powerful AI assistant.

By giving an AI (like Gemini, ChatGPT, or Claude) a specialized "persona," we can turn it into an expert script developer that understands all the specific rules and formats required for Ninja RMM scripting. This saves you time, reduces errors, and ensures all your scripts are consistent.

## 2. What's Included

* **`AIPrompt.md`**: This is the master prompt file. Think of it as the "brain" or "instruction manual" for the AI. It contains the persona, all the technical rules for Ninja RMM scripting, and the complete PowerShell template.
* **`Template.ps1`**: This is the standard PowerShell boilerplate script. **You do not need to use this file directly.** It is included for your reference, but it is already embedded inside the `AIPrompt.md` file for the AI to use automatically.

## 3. How to Use

Follow these three simple steps to start generating scripts.

### Step 1: Start a New AI Chat Session

For the best results, **always start a new, fresh chat session** with your chosen AI platform (Gemini, ChatGPT, Claude, etc.). This ensures the AI has a clean slate and isn't influenced by previous conversations.

### Step 2: Load the "NinjaScript Architect" Persona

Open the `AIPrompt.md` file. Select and copy the **entire contents** of the file. Paste this entire block of text as your **very first message** into the new chat window and send it.

The AI will now have its instructions and is ready to act as your Ninja RMM scripting expert.

### Step 3: Make Your Request

You can now ask for scripts in plain English! The AI will take your request and generate a complete, ready-to-use script based on the rules and template it just learned.

## 4. Example Requests

Here are a few examples of how you can ask for scripts:

#### **To Create a New Script:**

> "Create a script to check if the Windows Firewall is enabled for the Domain, Private, and Public profiles. If any are disabled, create an alert."

#### **To Convert an Existing Script:**

> "Please convert the following PowerShell script into a proper Ninja RMM component. Make sure to replace the hard-coded path with a configurable RMM variable."
>
> ```powershell
> $logFile = "C:\temp\applog.txt"
> if (Test-Path $logFile) {
>     Write-Host "Log file exists."
> } else {
>     Write-Error "Log file NOT found!"
> }
> ```

#### **To Modify a Script the AI Just Made:**

> "That's great. Now, can you modify the firewall script to also write the status of each profile (e.g., "Domain: On, Private: Off") to the custom field?"

## 5. Tips for Best Results

* **One Persona Per Chat:** Use your "NinjaScript Architect" chat session *only* for generating Ninja RMM scripts. If you need to ask the AI about something else, start a different chat.
* **Review the Variables:** The AI will always list the RMM Script Variables you need to create at the top of the script. Double-check that you create these in the Ninja RMM policy.
* **Iterate and Refine:** Don't be afraid to ask for changes. The AI is designed to modify and improve the scripts it creates.