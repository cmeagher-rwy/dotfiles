# Trial report: an always-on Caddy for local names, and Cloudflare Tunnel for public ones

Trial run on 2026-11-11 and 2026-11-12 on a Windows 11 laptop with WSL 2 (Debian, NAT networking), following [the trial brief](2026-11-11-caddy-service-trial.md). Every change made during the trial has been undone, apart from a few small leftovers (logs, npm caches, and state files Caddy rewrites itself). Scratch Vite and Next.js apps and an echo server stood in for real projects. The record of changes and the findings for specific projects are kept privately, not in this report.

Names are placeholders: `example.com` is the team's public domain, `<team>.cloudflareaccess.com` its Cloudflare Access login domain, and `*.dev.example.net` the names of the IIS sites on the machine.

Each step in the guides is marked **tested here** (run on this laptop during the trial), **observed here** (seen on this laptop, but not set up by the trial) or **docs only** (taken from the linked documentation, not run). Where a document doesn't say something, the report says so.

## Recommendations

| Question | Recommendation | Why |
|---|---|---|
| Where Caddy runs, on Windows + WSL | **B: Caddy on Windows, as a Windows service** | It serves dev servers on both Windows and WSL (WSL's through localhost forwarding), runs whenever Windows does, and makes the Windows-only and Windows + WSL set-ups the same, so there are two set-ups to document (Windows, macOS) rather than three. Trusting its certificate authority is one `caddy trust`. Option A can't reach dev servers on Windows (under NAT, WSL can't reach Windows' loopback; tested here with the Windows Caddy), and only runs while WSL does. |
| IIS | **1: switch by hand** (`iisreset /stop`, then `sc.exe start caddy`, and the reverse) | Tested here: two commands each way, nothing to configure and nothing to undo. Option 2 changes every HTTP.sys user on the machine and the hosts file of everyone who uses IIS; option 3 changes every IIS site's bindings. Both are assessed below. |
| Where a tunnel points | **The dev server's port, by default** | Tested here with Vite and Next: Cloudflare passes the public Host header through, so the only change is adding the public name to the dev server's host check. It keeps working while Caddy is stopped (for example while IIS is running). Point at Caddy instead when a project's routing lives in its Caddy site (several services behind one name); that was tested too, and needs `trusted_proxies` (see the Windows guide, step 9). |

Running Caddy as a Windows service the way its docs describe carries three risks:

- **The admin API.** Caddy's docs create the service as LocalSystem, the default for `sc.exe create`. Caddy's admin API (`localhost:2019`) accepts a new configuration from any local process without admin rights; this was shown here when `caddy reload` worked from an ordinary terminal. Anything running as the user can therefore reconfigure a process running as SYSTEM, for example to serve files it couldn't otherwise read. Running the service as `NT AUTHORITY\LocalService` would reduce this, but isn't what Caddy's docs describe and wasn't tested. Weigh it before adopting the set-up.
- **The sites folder.** `C:\ProgramData` lets ordinary users create files in its subfolders, and gives them full control of the files they create (its permissions, read here). So an ordinary user, or any process they run, can probably add a `.caddy` file to `C:\ProgramData\Caddy\sites` that the service loads on its next reload or start. They can't change the files an administrator created. This wasn't tested. It's the same kind of risk as the admin API, and closing it would mean changing the folder's permissions, which the trial avoided.
- **Tools inside WSL can't reach the names** under NAT networking (tested: connection refused). They can still reach a dev server directly on `localhost:<port>`. WSL's mirrored networking mode would fix this, with side effects assessed below.

## Moving a project onto the service

Projects that run their own `caddy run` with a project `Caddyfile` move over like this. Project-specific findings aren't included here.

- **Its sites file** (`sites\<project>.caddy`): the project's site blocks as they are, with upstreams on `127.0.0.1:<port>` instead of `localhost:<port>`. WSL's forwarding was seen covering `::1` too, but `127.0.0.1` is the address every set-up here was tested with. `header_up Host {upstream_hostport}` can stay.
- **Its global options removed.** An imported file can't hold global options ([import](https://caddyserver.com/docs/caddyfile/directives/import)), and the common ones aren't needed:
  - `http_port 80` and `https_port 443` are Caddy's defaults.
  - `local_certs` makes every site on the machine use Caddy's own authority; `.localhost` names already do ([Automatic HTTPS](https://caddyserver.com/docs/automatic-https)).
  - `auto_https disable_redirects` in the shared top file would turn off HTTP-to-HTTPS redirects for every project. A plain-HTTP site shouldn't need it, as an `http://` address is served over HTTP whatever the redirect setting (not tested).
- **`file_server` alongside `reverse_proxy`** never runs: in Caddy's [directive order](https://caddyserver.com/docs/caddyfile/directives#directive-order), `reverse_proxy` comes before `file_server` and handles every request in the site. If it did run under the service, it would serve from the service's working directory, not the project. Remove it, after checking with whoever knows the project what it was meant to do.
- **Scripts** that start the dev server and `caddy run` together go; the service replaces them, and the project's script for the dev server alone starts it. `next dev` listens on every address by default; adding `-H 127.0.0.1` keeps it off the network.
- **Docs** that describe the project's own Caddy would point at the team guide instead.
- **Tools in WSL that use the names** (for example an HTTP client's environment pointing at a `.localhost` name) won't work under NAT networking. Use the dev server's `localhost:<port>` from WSL.
- **Names for other tools:** a `.localhost` name needs a hosts entry for tools other than browsers (Windows guide, step 6).
- **A public name**, if the project is ever tunnelled, needs adding to the dev server's host check, e.g. `allowedDevOrigins` in `next.config.js` (tested with a scratch Next app).
- **Two projects with the same upstream port** still can't run at the same time; the service doesn't change that.

## Team guide: Windows (also Windows + WSL)

The Windows + WSL differences are in [their own section](#team-guide-windows--wsl-differences).

1. **Install Caddy machine-wide** *(tested here)*. In PowerShell run as administrator, download the Windows build and its checksums from [Caddy's GitHub releases](https://github.com/caddyserver/caddy/releases) (linked from [Install](https://caddyserver.com/docs/install)), check the zip's SHA-512, and unzip it into a folder only administrators can write to:

   ```powershell
   cd $env:USERPROFILE\Downloads
   Invoke-WebRequest https://github.com/caddyserver/caddy/releases/download/v2.11.9/caddy_2.11.9_windows_amd64.zip -OutFile caddy_2.11.9_windows_amd64.zip
   Invoke-WebRequest https://github.com/caddyserver/caddy/releases/download/v2.11.9/caddy_2.11.9_checksums.txt -OutFile caddy_2.11.9_checksums.txt
   (Get-FileHash caddy_2.11.9_windows_amd64.zip -Algorithm SHA512).Hash
   Select-String windows_amd64.zip caddy_2.11.9_checksums.txt
   New-Item -ItemType Directory 'C:\Program Files\Caddy'
   Expand-Archive caddy_2.11.9_windows_amd64.zip -DestinationPath 'C:\Program Files\Caddy'
   ```

   Use the latest release's version in the file names. Only expand the zip if the two hashes match ([Get-FileHash](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash), [Expand-Archive](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.archive/expand-archive)). Don't use a per-user install (such as winget's default) for the service: the user can overwrite that file, and the service would run it as SYSTEM.

2. **Create the configuration** *(tested here)*. As administrator, create `C:\ProgramData\Caddy\sites`, then `C:\ProgramData\Caddy\Caddyfile`:

   ```
   {
   	# Bind sites to loopback only, so dev servers aren't exposed to the network
   	default_bind 127.0.0.1 [::1]
   }

   import sites/*.caddy
   ```

   - **Notepad adds `.txt`** to a name without an extension, even with the full path on the command line: in the Save dialog, set *Save as type* to *All files*.
   - `default_bind` ([global options](https://caddyserver.com/docs/caddyfile/options)) keeps every site, and the HTTP-to-HTTPS redirect server, on loopback (tested here: nothing listened on other addresses).
   - `import sites/*.caddy` reads every file in `sites` ([import](https://caddyserver.com/docs/caddyfile/directives/import)). A site written straight into the top file works alongside them (tested here).
   - Caddy warns "Caddyfile input is not formatted" when tabs and spaces are mixed; it's harmless, and `caddy fmt --overwrite <file>` tidies the file.

3. **Create the service** *(tested here)*. In PowerShell 7 (`pwsh`) run as administrator:

   ```powershell
   sc.exe create caddy start= demand binPath= '"C:\Program Files\Caddy\caddy.exe" run --config C:\ProgramData\Caddy\Caddyfile'
   sc.exe start caddy
   ```

   - This follows [Running Caddy](https://caddyserver.com/docs/running) ("Windows service") and [sc create](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create). Only `pwsh` was used here. Windows PowerShell 5.1 is expected to pass the inner quotes to `sc.exe` incorrectly, and in Command Prompt the form would be `binPath= "\"C:\Program Files\Caddy\caddy.exe\" run --config C:\ProgramData\Caddy\Caddyfile"` (neither tested).
   - `--config` is needed because a service starts in `C:\Windows\System32`, where `caddy run` would otherwise look for a `Caddyfile`.
   - `start= demand` means the service starts only when asked, so it doesn't compete with IIS at boot. Without IIS, `start= auto` (as in Caddy's docs) starts it with Windows *(docs only)*.
   - The service keeps its data, including its certificate authority's private key, in `C:\Windows\System32\config\systemprofile\AppData\Roaming\Caddy` (tested here).
   - Starting and stopping it (`sc.exe start caddy`, `sc.exe stop caddy`) needs administrator rights.
   - A Windows service's output goes nowhere. To see Caddy's log while setting up, add this to the global options block, and remove it afterwards (Caddy rejects the block written on one line):

     ```
     	log {
     		output file C:/ProgramData/Caddy/caddy.log
     	}
     ```
   - On every start, the service tries to install its root into a trust store and logs "failed to install root certificate". That's expected; step 5 trusts it instead. Caddy's `skip_install_trust` global option ([global options](https://caddyserver.com/docs/caddyfile/options)) would stop the attempts; it was left out of the trial to keep the configuration minimal.

4. **Add a project's sites** *(tested here)*. As administrator, put one file per project in `C:\ProgramData\Caddy\sites`, named `<project>.caddy`, holding that project's site blocks with upstreams on `127.0.0.1`:

   ```
   www.example.localhost {
   	reverse_proxy 127.0.0.1:3000
   }
   ```

   Then tell Caddy to reload, as [Running Caddy](https://caddyserver.com/docs/running) says Windows services can't be reloaded. It works from an ordinary terminal (tested here), as it goes through the admin API:

   ```powershell
   & 'C:\Program Files\Caddy\caddy.exe' reload --config C:\ProgramData\Caddy\Caddyfile
   ```

   A dev server stopped behind a working site returns `502` until it's started again (tested here).

5. **Trust Caddy's certificate authority** *(tested here)*. With the service running, in a terminal run as administrator:

   ```powershell
   & 'C:\Program Files\Caddy\caddy.exe' trust
   ```

   - [`caddy trust`](https://caddyserver.com/docs/command-line#caddy-trust) fetches the root from the admin API. On Windows it installs into the **current user's** Trusted Root Certification Authorities, even when run as administrator, after a Windows security dialog asking to confirm (tested here). Chrome then accepted the certificates (Edge and Firefox weren't tried).
   - Run it as the account you browse with. If you elevate with a separate administrator account, the root would go into that account's store instead. Whether it works without elevation wasn't tested.
   - To remove it later: `certutil -user -delstore Root <thumbprint>` ([certutil](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certutil); tested here), or `caddy untrust` while the service is running *(docs only)*. PowerShell's `Remove-Item Cert:\CurrentUser\Root\<thumbprint>` fails with "The operation is on user root store and UI is not allowed" (tested here).

6. **Make `.localhost` names resolve for tools other than browsers** *(tested here)*. Browsers resolve any `*.localhost` name to the local machine by themselves; Windows' own resolver doesn't (tested here through Windows PowerShell 5.1's .NET: a `.localhost` name without a hosts entry didn't resolve, while one with an entry did). Node wasn't tested. As administrator, add each name to `C:\Windows\System32\drivers\etc\hosts`:

   ```
   127.0.0.1 www.example.localhost
   ```

7. **A name for any port** *(tested here, optional)*. A wildcard site lets `5173.port.localhost` reach `127.0.0.1:5173`, for ports on an allowed list only. Save as `sites\ports.caddy`:

   ```
   *.port.localhost {
   	@allowed host 3002.port.localhost 3003.port.localhost 3004.port.localhost 3005.port.localhost 3006.port.localhost 3007.port.localhost 3008.port.localhost 3009.port.localhost 4000.port.localhost 5173.port.localhost 8080.port.localhost
   	handle @allowed {
   		reverse_proxy 127.0.0.1:{labels.2}
   	}
   	handle {
   		respond 403
   	}
   }
   ```

   - `{labels.2}` is the third label counting from the right, starting at 0 (`localhost` is 0, `port` is 1, `3000` is 2). Caddy's [Go package documentation](https://pkg.go.dev/github.com/caddyserver/caddy/v2/modules/caddyhttp) describes host labels as 0-based from the right, and testing confirmed it. Caddy allows a placeholder in an upstream without a scheme as long as it supplies the port ([reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy), "Upstream addresses").
   - Tested here: an allowed port with a server returns its page; an allowed port with nothing on it returns `502`; a port not on the list (including the admin API's 2019) returns `403`. Chrome accepts the wildcard certificate (`*.port.localhost`, valid for 12 hours and renewed by Caddy).
   - Keep the list to ports you're happy for any `*.port.localhost` page to reach. The list here leaves out 2019 (Caddy's admin API) and 3000, 3001, 6006 and 6007, which the trial's user keeps for their own servers.

8. **Dev servers' host checks** *(tested here with Vite 8.3.8 and Next 16.4.6)*.
   - Behind Caddy on a `.localhost` name, neither needs a change. [Vite's `server.allowedHosts`](https://vite.dev/config/server-options#server-allowedhosts) allows `localhost`, names under `.localhost` and IP addresses by default; [Next's `allowedDevOrigins`](https://nextjs.org/docs/app/api-reference/config/next-config-js/allowedDevOrigins) allows `localhost` and its subdomains. Hot reload (HMR) worked through Caddy for both.
   - Bind dev servers to `127.0.0.1` (Vite `--host 127.0.0.1`, Next `-H 127.0.0.1`). Sites point at `127.0.0.1`, which Vite's default `localhost` may not listen on, and it keeps them off the network. No Windows Firewall prompt appeared (tested here).

9. **Run a tunnel for a public name** *(tested here)*. The admin creates the tunnel and gives you its token (see the [admin's guide](#admins-guide-cloudflare-tunnel)).
   - **Install `cloudflared`:** download the Windows installer from [Cloudflare's downloads page](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/) *(docs only; it was already installed here)*.
   - **Keep the token in a file only you can read,** e.g. `%USERPROFILE%\.cloudflared\<tunnel>.token`: paste it into Notepad and save it there (the name has an extension, so Notepad won't add `.txt`). Never paste it into a terminal or chat.
   - **Run it** in an ordinary terminal, and stop it with Ctrl+C:

     ```powershell
     cloudflared tunnel run --token-file "$env:USERPROFILE\.cloudflared\<tunnel>.token"
     ```

     [`--token-file`](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/cloudflared-parameters/run-parameters/) keeps the token out of shell history and the process list. A `--token` option or `TUNNEL_TOKEN` environment variable would take precedence over the file.
   - **What the local service receives** (tested here): the public Host header (`<person>-<app>.example.com`) unchanged, `X-Forwarded-Proto: https`, and the request body.
   - **The dev server's host check** has to allow the public name (tested here): Vite answers `403 Blocked request. This host is not allowed` until `server.allowedHosts: ['<name>']` is in `vite.config.js` (a newly created config file needs a Vite restart); Next serves the page but blocks HMR ("Blocked cross-origin request to Next.js dev resource /_next/webpack-hmr") until `allowedDevOrigins: ['<name>']` is in `next.config.*` (Next restarts itself when that file changes). With those, HMR worked over the public name for both.
   - **A dev server shows error overlays and stack traces** to whoever can load the page. Put Access in front of anything but a webhook endpoint (see the admin's guide).
   - **Pointing the tunnel at Caddy instead** (tested here). Serve the public name as a plain-HTTP site on its own port, so Caddy doesn't try to get a public certificate ([addresses](https://caddyserver.com/docs/caddyfile/concepts#addresses)) and the port isn't IIS's 80:

     ```
     http://<person>-<app>.example.com:5399 {
     	reverse_proxy 127.0.0.1:3000
     }
     ```

     and add to the top file's global options:

     ```
     	# Trust X-Forwarded-* headers only from loopback, where cloudflared connects from,
     	# so apps behind Caddy see the public scheme (https) and the real client address
     	servers {
     		trusted_proxies static 127.0.0.1/32 ::1/128
     	}
     ```

     Without `trusted_proxies`, Caddy replaces the headers `cloudflared` sends, as [reverse_proxy's header defaults](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy) describe: the app sees `X-Forwarded-Proto: http` and `X-Forwarded-For: 127.0.0.1`. With it, the app sees `https` and the visitor's address followed by `127.0.0.1` (tested here). A request with a Host no site matches gets an empty `200`. The tunnel's Service URL is then `http://127.0.0.1:5399`, and the name is down whenever Caddy is (for example while IIS runs).

10. **IIS** *(tested here)*. IIS holds ports 80 and 443 on every address, so it and Caddy take turns. In a terminal run as administrator:

    ```powershell
    # Caddy on
    iisreset /stop
    sc.exe start caddy
    # IIS back
    sc.exe stop caddy
    iisreset /start
    ```

    - `iisreset /stop` stops W3SVC and WAS and frees both ports; the HTTP service (HTTP.sys) keeps running, so printing and other services that depend on it (SSDP Discovery, WinRM and others) are unaffected (tested here). Start types aren't changed, so IIS starts with Windows as before. The trial found no current Microsoft reference page for `iisreset` (the old one returns 404); `iisreset /?` lists the options.
    - Run nothing else that wants port 80 or 443 at the same time, including a project's own `caddy run`.

## Team guide: Windows + WSL differences

Everything in the Windows guide applies; Caddy runs on Windows, not in WSL.

- **Dev servers in WSL** are reached through WSL's localhost forwarding (`localhostForwarding`, on by default in [`.wslconfig`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)), so sites files point at `127.0.0.1:<port>` exactly as for a Windows dev server (tested here, including HMR). Forwarding covered `127.0.0.1` and `::1` for a WSL server listening on all addresses (observed here).
- **Don't run Caddy in WSL** as well: its localhost forwarding would compete for ports 80 and 443. It also forwards a WSL Caddy's admin API to Windows' `127.0.0.1:2019` (observed here).
- **Tools inside WSL can't reach the names** under NAT networking (tested here). Use `http://localhost:<port>` from WSL, or see [mirrored networking](#wsls-mirrored-networking-on-paper).
- **Names from the Windows hosts file resolve in WSL** through WSL's DNS forwarding (`nameserver 10.255.255.254` in `/etc/resolv.conf`): both `.localhost` and other names in it did (observed here, WSL 3.0.3). WSL's own `/etc/hosts` isn't involved. They resolve to `127.0.0.1`, which in WSL is WSL's own loopback, so under NAT they still don't reach Caddy on Windows. Names not in the Windows hosts file don't resolve in WSL, except in `curl`, which resolves `*.localhost` itself.

## Team guide: macOS (docs only)

None of this was tested.

1. **Install:** `brew install caddy` ([Install](https://caddyserver.com/docs/install), "Homebrew": community-maintained).
2. **Run as a service:** `brew services start caddy` starts it now and at login ([Homebrew's caddy formula](https://formulae.brew.sh/formula/caddy)). Caddy's own [Running Caddy](https://caddyserver.com/docs/running) doesn't cover macOS.
3. **The top `Caddyfile` and sites folder:** the formula's service runs `caddy run --config $(brew --prefix)/etc/Caddyfile`, with its data in `$(brew --prefix)/var/lib` and its log in `$(brew --prefix)/var/log/caddy.log` ([the formula's source](https://github.com/Homebrew/homebrew-core/blob/main/Formula/c/caddy.rb)). Put the same top file as on Windows there, with `sites/` beside it.
4. **Adding sites and reloading:** as on Windows, then `caddy reload --config $(brew --prefix)/etc/Caddyfile`.
5. **Trust:** `caddy trust` ([command line](https://caddyserver.com/docs/command-line#caddy-trust); it may ask for a password to change the system keychain).
6. **Names for other tools:** add `127.0.0.1 <name>` lines to `/etc/hosts`.
7. **`cloudflared`:** `brew install cloudflared` ([downloads](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/)), then `cloudflared tunnel run --token-file <file>`.
8. **IIS:** not applicable.

Still to check on a Mac: whether the service, running as the user, can bind ports 80 and 443, and whether `caddy trust` finds its authority in `$(brew --prefix)/var/lib`.

## Admin's guide: Cloudflare Tunnel

The dashboard steps below are as found in Cloudflare's dashboard on 2026-11-12 (tested here). Cloudflare's [create a tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/) page describes the same flow.

**Setting up a team member** (names are `<person>-<app>.example.com`, provisional):

1. **Create their tunnel:** Networking → Tunnels → create a tunnel with the *Cloudflared* connector, named for the person. Copy the token from the install command it shows; don't run the command.
2. **Hand over the token** privately, the way you'd hand over a password. It runs that tunnel and nothing else.
3. **Add each hostname:** Networking → Tunnels → *Configure* on the tunnel → *Routes* tab → *Add route* → *Published application*. Enter the subdomain, choose the domain, and set *Service URL* with its scheme, e.g. `http://127.0.0.1:3000` (use `127.0.0.1` rather than `localhost` when the dev server listens on IPv4 only). There's no separate service-type selector. *Additional application settings* vary with the type; for HTTP they include a Host header override and disabling chunked encoding; defaults were used here.
4. **Optionally, put Access in front:** Zero Trust → Access controls → Applications → *Create new application* → *Self-hosted and private* → *Public DNS*. Add the hostname with no path and an *Allow* policy (e.g. the person's email, with the one-time PIN login). To leave a webhook path open, add a second application for the same hostname with the path (e.g. `webhook`) and a *Bypass* policy for *Everyone* ([policies](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/), [application paths](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/)). Tested here:
   - every other path, including `POST /`, redirects to `<team>.cloudflareaccess.com` for login, and the one-time PIN login got through;
   - the bypass path covers everything under it (`/webhook/sub`) but not lookalikes (`/webhookx`), and **matches regardless of case** (`/Webhook` was open too);
   - requests through a Bypass carry no Access token (`Cf-Access-Jwt-Assertion`). Access doesn't log them either, per the policies page (not checked here).
5. **Turn on [Always Use HTTPS](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/always-use-https/) for the zone.** Without it, a tunnel hostname requested over `http://` is served over plain HTTP rather than redirected (tested here).

Hostnames are one level deep because the free Universal SSL certificate covers `example.com` and `*.example.com` only (seen on the trial hostname: issued by Google Trust Services through Cloudflare).

**When someone leaves**, in this order (tested here, except the token refresh):

1. **Routes:** delete each of their published application routes, and check DNS → Records for a CNAME left pointing at `…cfargotunnel.com`.
2. **Access:** delete their Access applications (bypass ones first).
3. **The tunnel:** delete it from Networking → Tunnels, which also makes its token useless. In the trial its connector had already stopped; deleting a tunnel whose `cloudflared` is still connected wasn't tried. To keep the tunnel but cut off an old token instead, use *Refresh token* on the tunnel's Overview; `cloudflared` can no longer make new connections with the old one ([tunnel permissions](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/remote-tunnel-permissions/)) *(docs only)*.

Nobody else runs `cloudflared tunnel login`, as the `cert.pem` it creates controls every tunnel in the account.

## IIS options 2 and 3, on paper

**Option 2: move HTTP.sys to another loopback address** (not recommended now).

- `netsh http add iplisten 127.0.0.2` scopes the addresses the HTTP service binds to ([add iplisten](https://learn.microsoft.com/en-us/windows/win32/http/add-iplisten)). It applies to the HTTP service as a whole, not just IIS. On this laptop that includes an unnamed registration on `http://127.0.0.1:8884/`, which would most likely stop answering on `127.0.0.1`.
- Microsoft's pages don't say whether the HTTP service has to restart for the change to take effect, or that an empty list means every address. Restarting the HTTP service stops everything that depends on it; here, that includes the Print Spooler and SSDP Discovery as well as IIS.
- Every IIS user would also point their IIS sites' hosts entries (`*.dev.example.net`) at `127.0.0.2`, and an IIS site on a `.localhost` name can't move, as browsers resolve those to `127.0.0.1` themselves.
- It would let IIS and Caddy run together, so it may be worth a separate trial if switching by hand becomes a nuisance.

**Option 3: Caddy in front of IIS** (not recommended).

- Every IIS site's bindings would move to other ports (`applicationHost.config`), with their SNI certificate bindings re-registered in HTTP.sys for the new ports, and Caddy would forward each IIS site's name to IIS.
- Apps that build URLs from the port or scheme they see, or that don't read `X-Forwarded-*`, would break. Sites using Windows authentication wouldn't pass it through a proxy without extra work. Undoing it means restoring every binding.
- It's the most work to set up and undo.

## WSL's mirrored networking, on paper

From [WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking) and [WSL configuration](https://learn.microsoft.com/en-us/windows/wsl/wsl-config); not tested, and `.wslconfig` wasn't changed.

- **For B:** with `networkingMode=mirrored`, Linux reaches Windows servers on `127.0.0.1` (not `::1`), so tools in WSL would reach the Windows Caddy. `localhostForwarding` is ignored; Windows reaches Linux on `localhost` directly, so sites pointing at `127.0.0.1:<port>` for WSL dev servers should still work.
- **For A:** Windows would still reach a WSL Caddy on `localhost`.
- **Shared ports:** in mirrored mode Windows and WSL share one set of ports, so a WSL dev server and a Windows process can't both use the same port, and Caddy on Windows would hold 80 and 443 for both.
- **Docker Desktop:** Docker's docs don't mention mirrored mode. WSL's configuration docs give an example of letting Docker Desktop bind port 53 in mirrored mode (`ignoredPorts`). Check Docker Desktop on a test machine first.
- **Inbound connections** from other machines need Hyper-V firewall rules (`Set-NetFirewallHyperVVMSetting`).

## Tailscale

Not used here; flagged only. `default_bind 127.0.0.1 [::1]` doesn't stop `tailscale serve` on another machine from reaching Caddy through `localhost`. But Caddy only answers the names it has sites for: a `tailscale serve` that proxies to Caddy sends the request on with a Host that no site matches (Tailscale's docs don't say which Host it sends), and Caddy returns an empty `200`. Such a machine would need a site for its Tailscale name, like the `http://` site used for the tunnel above. [`tailscale serve`](https://tailscale.com/kb/1312/serve) can proxy to a local HTTPS server with a certificate it doesn't trust using `https+insecure://`.

## Keeping copies of sites files

One file per project in the shared `sites` folder, copied from the project, works but drifts: the copy isn't updated when the project's routing changes. Changing a file an administrator created needs administrator rights (or `sudo`); on Windows an ordinary user can probably add new files (see the sites folder risk under [Recommendations](#recommendations)). Projects already keep their routing in a `Caddyfile`, which mostly needs only the global options removed and upstreams changed to `127.0.0.1`, so a project's file can be the source: the team guide would say "copy `<project>/Caddyfile` to `sites\<project>.caddy`, then reload". A small cross-platform script (PowerShell 7 runs on all three systems) could do the copy and reload, but it would still need administrator rights to write the file, so start with the documented copy and add a script only if the copies keep drifting.

## Follow-up: recommended dotfiles changes

A list, not an edit; nothing in the repository was changed by the trial.

- **WSL: retire Caddy once projects stop running `caddy run` there.** Under B, nothing in WSL needs Caddy: `Install-Caddy` (apt repo, package, disabled service) and `Enable-UnprivilegedLowPorts` (`/etc/sysctl.d/50-unprivileged-ports.conf`, `ip_unprivileged_port_start=80`) would get retire steps in `lib/Retire.psm1`. Until then, keep both as they are; the Debian conffile question doesn't arise, as `/etc/caddy/Caddyfile` stays the package's own.
- **Windows: install Caddy and its service.** The dotfiles' scripts run in WSL today. Either document the Windows guide's steps 1 to 5 in `windows/` (reference docs), or add a Windows-side script; the steps need administrator rights either way.
- **Windows: trusting the authority** is `caddy trust` after the service starts; include it in the same place.
- **`cloudflared`:** install on Windows (installer from Cloudflare's downloads page) and macOS (`brew install cloudflared`); nothing in WSL.
- **IIS:** document the switch commands in `windows/`.
- **macOS:** the dotfiles target Windows, WSL and Linux only, so the macOS guide would live in the team's docs rather than here.
- **Caddy's own trust attempts:** `skip_install_trust` in the top Caddyfile would stop the service's failed attempts to install its root at each start (and, in WSL, the "user NOT in sudoers" log entries). The trial left it out; worth deciding when the top file is settled.
- **Agents and Cloudflare's docs:** during the trial, the agent's directions for Cloudflare's dashboard were out of date (tunnels are under Networking → Tunnels; a hostname is added from the tunnel's *Configure* → *Routes* → *Add route* → *Published application*; *Service URL* takes the scheme and there's no service-type selector). Look into installing Cloudflare's agent skills, or docs access, for the coding agent, so agents work from current Cloudflare docs.
- **Old Caddy roots:** once the service replaces per-user and per-project Caddy, the roots those made in the Windows user's store and the Linux store, the per-user winget Caddy, and its `%APPDATA%\Caddy` folder become unused. Whether to remove them is the user's call.

## Corrections to the brief, and other findings

- **The Linux unit's capabilities:** `AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE`, not only the second.
- **`/var/lib/caddy` held no certificate authority before the trial:** the service created one when it first ran.
- **The low-ports sysctl** is set by `/etc/sysctl.d/50-unprivileged-ports.conf` (`ip_unprivileged_port_start=80`).
- **HTTP.sys:** the Print Spooler, SSDP Discovery, WinRM and others depend on the HTTP service, so stopping IIS with `iisreset /stop` (which leaves HTTP running) is the safe way.
- **Name resolution in WSL:** names in the Windows hosts file do resolve in WSL, through WSL's DNS forwarding. `.localhost` names that aren't in it resolve only in `curl`.
- **Name resolution on Windows:** apps other than browsers don't resolve `*.localhost` names without a hosts entry.
- **WSL's localhost forwarding** listens on Windows' loopback addresses only (`127.0.0.1` and `::1`).
- **The Linux service tries to install its root** with `sudo` at each start and reload, and logs "user NOT in sudoers". Harmless, but noisy.
- **Undoing a Linux trust:** `caddy untrust` removed its file and rebuilt the bundle but left two dangling links in `/etc/ssl/certs`; `sudo update-ca-certificates --fresh` removed them (tested here).

## What couldn't be checked

- **WSL restart** (names down until WSL starts, then back by themselves): not run, at the user's request, as it ends every WSL terminal.
- **The real projects:** client projects were excluded, so scratch Vite and Next apps stood in for them.
- **macOS:** docs only.
- **IIS options 2 and 3, and WSL's mirrored networking:** on paper only, including whether `netsh http add iplisten` needs the HTTP service restarted, and how Docker Desktop behaves in mirrored mode.
- **The Windows service at boot** (`start= auto`) and as `NT AUTHORITY\LocalService`.
- **Whether Caddy or WSL's forwarding can bind `127.0.0.1:443` while IIS holds `0.0.0.0:443`:** every test stopped IIS first.
- **A dev server listening on all addresses on Windows,** and the Windows Firewall prompt it may cause.
- **Whether deleting a tunnel route also deletes its DNS record:** the user deleted both.
- **Whether an ordinary user can add files to `C:\ProgramData\Caddy\sites`:** inferred from `C:\ProgramData`'s permissions after the folder had been removed.
- **Browsers other than Chrome**, and `caddy trust` without elevation.
