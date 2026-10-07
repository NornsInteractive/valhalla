# Valhalla Privacy Policy

Effective and last updated: October 7, 2026  
Application: Valhalla  
Publisher: Norns Interactive  
Privacy contact: [norns.soft@gmail.com](mailto:norns.soft@gmail.com)

[简体中文](PRIVACY.md)

## 1. Scope

This policy explains how the Valhalla Windows application accesses, uses, stores, and transmits data for remote server management, terminals, file transfers, AI Agent sessions, and optional NAS media features. Available features depend on your version, settings, and configured services.

Valhalla is a client for services you specify and does not require a Valhalla account. The current version has no advertising SDK, advertising identifier tracking, or usage analytics service that reports to the publisher. It does not automatically upload server configurations, credentials, files, sessions, or diagnostic logs to Norns Interactive, or sell or use that data for advertising profiles.

Local storage does not mean every feature works offline. Server connections, AI features, file transfers, media playback, and casting transmit relevant data to services or devices you configure or select.

## 2. Data and purposes

| Category | Data processed | Purpose |
| --- | --- | --- |
| Connections and authentication | Server names, addresses, ports, usernames, SSH host key records, supplied passwords and SSH private keys, optional sudo passwords, and media source accounts, passwords, or tokens | Save connections, verify server identity, authenticate, and perform requested operations. SSH private keys are used locally for authentication and are not sent to the SSH server as private key files |
| Server management | Resource metrics, processes, services, containers, logs, terminal input and output, quick commands, and working paths | Display server status, run commands, and return results |
| Files and sessions | Files and attachments you select or authorize, paths and file contents, prompts, messages, drafts, tool calls and results, session identifiers, and Agent configuration | Browse, edit, and transfer files; provide AI sessions, history, and session recovery |
| Media | Source addresses, folders, filenames, metadata, thumbnails, favorites, playlists, playback progress, and content needed for previews, playback, or downloads | Index, browse, play, resume, download, and optionally cast media |
| Settings and diagnostics | Interface preferences, language, window bounds, connection preferences, startup timestamps, errors, and stack traces | Preserve preferences, restore windows, and troubleshoot failures |

Terminal output, files, sessions, media metadata, and errors may contain personal or sensitive information depending on your input and remote responses. These features do not require you to upload contacts, precise location, health information, or payment card information.

## 3. Local storage and security

General configuration and preferences are stored in application data on your device. Sessions and media indexes use local databases. Previews may create thumbnails or temporary caches; downloads and exports are saved to their respective locations. General settings, databases, caches, and exported files are not guaranteed to have application-level encryption; use operating system account controls and disk protection.

Connection passwords, SSH private keys, sudo passwords, and media credentials use operating system-supported secure storage. If secure storage is unavailable, some SSH credentials are retained only in the current process's memory; that memory copy is not retained after the process closes. Media credential persistence failures do not silently fall back to memory-only storage.

SSH/SFTP connections protect traffic using SSH; optional Mosh connections use Mosh's encrypted transport. Media connections may use HTTPS, SSH tunnels, SMB, or configured HTTP. Protection depends on the protocol, server, and configuration. HTTP and some local network casting traffic are not encrypted in transit; choose HTTPS, SSH tunnels, or trusted networks where needed. These measures reduce risk but cannot guarantee absolute security.

## 4. Network connections and third parties

Relevant data is transmitted as needed for the selected feature to the following recipients, which may be located outside your country or region:

- **Configured servers and media services:** Authentication information or authentication results, commands, file requests, uploaded content, playback requests, and related data go to the selected endpoint. Services can receive your source IP address and keep their own access logs.
- **Selected AI Agents, CLI tools, and model services:** Prompts, attachments, conversation context, tool results, and files or command output accessed under your permission settings may be sent through a remote Agent to its configured model provider. Codex, Claude, OpenCode, other Agents, and sign-in services may also process account information, authorization tokens, and network information. Some authorization data and session records are stored in the remote tool's data directories. Retention, model training use, and other processing depend on your selected tools, providers, and settings.
- **Selected casting devices:** Device discovery communicates on your local network. The chosen device receives media information, playback controls, and an address needed to retrieve media. The application may provide a temporary media relay.
- **Installation, download, and external link providers:** Remote tool installation, media service deployment, authorization, or external links may access official software distribution sites, package repositories, identity services, or websites you specify. Those providers process requests under their own policies.

These independent services are not data hosting services operated by Norns Interactive. Review the recipient's privacy policy and data settings before using the feature, and avoid submitting sensitive information unnecessary for your task.

Microsoft Store, Windows, and browsers may also process store account, installation, update, or system diagnostic data according to their own settings. This independent processing is not an upload by Valhalla to its publisher. See the [Microsoft Privacy Statement](https://www.microsoft.com/privacy/privacystatement) for Microsoft's practices.

## 5. Diagnostics and information you send us

The application records startup and error diagnostics locally and does not automatically upload them. Current logs rotate by size and retain up to three files of approximately 1 MiB each. Recognized credentials and other sensitive patterns are masked where possible; masking does not guarantee removal of all personal information. You can view and export diagnostics and should review them before sharing.

If you contact us by email, GitHub, or another channel, we receive the contact details, description, and attachments you submit. We use them to respond, troubleshoot, or handle privacy requests. Email providers and GitHub process submissions under their own policies. Do not post passwords, private keys, tokens, complete personal data, or unchecked logs in public issues.

## 6. Retention and deletion

Local configuration, credentials, preferences, sessions, and media indexes may remain for continued use until you delete the corresponding data or clear application data. Caches follow their cache management rules; diagnostic logs rotate under the size limits above. Closing the application does not delete downloaded or exported files.

Deleting a server or media source removes its connection configuration and requests deletion of associated secure storage credentials. It does not clear all history, caches, downloads, or remote data. Local AI history deletion and remote session deletion by independent CLI tools have different scopes; follow the operation's notice and the tool's behavior. Deleting local records does not guarantee deletion of migration backups, remote history, or data retained by third parties.

Uninstalling does not guarantee removal of manually saved downloads, exports, system backups, or remote records. For a complete cleanup, close the application, clear its application data and caches and separately saved files, and delete remote data or revoke authorization through the relevant provider.

Support or privacy request materials received by us are used for that request and deleted or de-identified when their purpose is complete, unless retention is required by law.

## 7. Choices and requests

You choose whether to add or connect to servers, enable automatic connections, use AI, add media sources, upload files, cast media, or export and share logs. You can disconnect, disable optional features, change or delete configurations, and revoke third-party authorization through that service. Stopping a connection does not recall information already transmitted.

You can access configurations, sessions, and media records through the application and manage them using available editing and deletion controls. Norns Interactive cannot directly access or delete data held only on your device or by your remote services, but can provide instructions. For information you submit to us, contact the address below to request access, correction, deletion, or exercise other applicable privacy rights.

## 8. Children

Valhalla is intended for remote server and Agent management and is not directed at children. Contact our privacy email if you believe a child has directly submitted personal information to us that should be deleted.

## 9. Updates

We will update this policy and its last updated date when application features or data practices change. Material changes will be explained in an appropriate location, and consent will be obtained where applicable requirements call for it.

## 10. Contact

Publisher: Norns Interactive  
Privacy email: [norns.soft@gmail.com](mailto:norns.soft@gmail.com)  
Project: [https://github.com/NornsInteractive/valhalla](https://github.com/NornsInteractive/valhalla)

Use email for requests containing private information and provide only what is needed to handle the request. We will not ask you to send server passwords, SSH private keys, or access tokens to make a privacy request.
