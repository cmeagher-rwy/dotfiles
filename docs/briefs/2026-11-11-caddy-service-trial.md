# Trial brief: an always-on Caddy for local names, and Cloudflare Tunnel for public ones

This brief is for an agent working on the user's Windows 11 laptop with WSL2 (Debian). Today, projects in WSL start their own Caddy (`caddy run` with a project `Caddyfile`) to serve local HTTPS names such as `www.app.localhost`. Your job is to try two things and report back:

1. **Local names:** a Caddy that runs all the time as a background service serves every project's local names, so projects stop running their own.
2. **Public names:** Cloudflare Tunnel exposes a local service on a name under the team's domain (`example.com` here), e.g. to receive webhooks.

The result has to become a guide others can follow in three set-ups:

- **Windows only:** projects, dev servers and browser all on Windows.
- **macOS.**
- **Windows + WSL:** projects and dev servers in WSL, browser on Windows (this machine).

So prefer what each tool documents over anything clever, and keep the set-ups as alike as you can. It's a trial: change as little as possible, and leave everything easy to undo.

## Decisions so far

- **Caddy alone.** An [earlier brief](2026-11-11-portless-trial-brief.md) proposed adding portless; it isn't needed and adds more than it gives.
- **Caddy runs the way its docs say for each OS** ([Running Caddy](https://caddyserver.com/docs/running)):
  - **Linux:** the packaged systemd service, which runs as the `caddy` user with its config in `/etc/caddy/Caddyfile`.
  - **Windows:** a Windows service, created with `sc.exe` or WinSW.
  - **macOS:** the docs don't cover it. Homebrew's `brew services` is the usual route (unverified).
  - **Not a systemd user service,** which Caddy's docs don't mention.
- **Local names keep Caddy's own certificate authority** (`*.localhost`). Real certificates under the team's domain for local names would need a custom Caddy build on every OS, and a token on every laptop that can edit the whole zone's DNS.
- **Public names go through Cloudflare Tunnel (`cloudflared`).** It's approved for this.
  - **Admins:** the domain's Cloudflare account has admins, who may add others.
  - **Tunnels:** an admin creates each person's remotely-managed tunnel and hostnames, and gives that person only the tunnel's token, which can run that tunnel and nothing else.
  - **`cert.pem`:** nobody else runs `cloudflared tunnel login`, because the `cert.pem` it creates controls every tunnel in the account.
- **Public names are one level deep: `<person>-<app>.example.com`** (provisional), e.g. `sam-shop.example.com`.
  - **Why one level:** the free Universal SSL certificate covers only `*.example.com`. A name like `shop.sam.example.com` needs the paid Advanced Certificate Manager, and Total TLS excludes Tunnel hostnames anyway.
  - **Sources:** [Universal SSL limitations](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/limitations/), [Total TLS](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/total-tls/).
- **Only what a typical developer would do, and only what's officially documented.** Every command, config line and tool must be one a typical developer would use, and covered by official docs (Caddy, Microsoft, Cloudflare, Vite, Next), so the team can be pointed at those docs for every step. Keep it as simple as possible. For example:
  - **IIS:** `iisreset /stop` and `iisreset /start`, not `Stop-Service`.
  - **Trust:** `caddy trust` and `caddy untrust`, falling back to importing `root.crt` on Windows by double-clicking it.
  - **Admin steps:** the user runs them in their own `sudo` or "Run as administrator" terminal.
  - **No extras:** no ownership or ACL changes, and no NSS modules.
- **Throwaway projects only.** The trial uses scratch Vite and Next.js apps and an echo server on uncommon ports (not 3000, 3001, 6006, 6007 or 2019), with names like `trial-next.localhost`. No client project is run, named or exposed. Where the steps below mention the first or second project, use these instead.
- **Site definitions can live in the main `Caddyfile`, in imported files, or both.** People choose; the trial tests both in one file.
- **Windows binary for option B:** Caddy's official download, put in `C:\Program Files\Caddy\`. Not winget's copy, Chocolatey or Scoop. The trial creates the service with Caddy's documented default account, LocalSystem; the report covers what that means.
- **Tailscale is out of scope.** It won't be used on this machine. Just flag anything that would stop Tailscale reaching Caddy through localhost (`tailscale serve`) on another machine.

## Nothing irreversible

This laptop is the user's daily driver and must stay working throughout. Before any change, know exactly how to undo it, and have checked that the undo works. If you can't say how to undo something, don't do it: describe it in the report instead.

- **Back up before overwriting:** copy any file you're about to overwrite or edit (e.g. `/etc/caddy/Caddyfile`) to a backup alongside it, and record both paths.
- **Never shut down WSL or restart Windows yourself:** no `wsl.exe --shutdown`, `wsl.exe --terminate` or reboot. They end every WSL terminal and agent the user has open. If a test needs one, ask the user to do it when it suits them, or skip the test and say so.
- **Never delete or uninstall** anything you didn't create in this trial, and never remove or overwrite a trusted certificate, a hosts-file entry, an IIS setting or an HTTP.sys setting.
- **Paper only:** no `netsh http` changes, no IIS configuration changes, and no `.wslconfig` changes. Assess them on paper. The only IIS change allowed is stopping its services for a test, with their state recorded and restored straight afterwards.
- **If something breaks:** stop and undo straight away, then tell the user what happened before doing anything else.

## Approvals

Anything marked *(approval)* below needs the user's go-ahead. Before each, present the exact commands and files it involves, and what undoes each. One approval covers that list; anything not on it needs a fresh one. *(approval)* covers:

- creating or changing any file outside your scratchpad;
- anything needing `sudo` or Windows administrator rights;
- installing anything;
- changing a trust store, `.wslconfig`, IIS or HTTP.sys;
- exposing anything publicly.

Never edit a project or this dotfiles repo; record what they'd need in the report.

## What's already known

Checked on 2026-11-11, so re-check anything that matters.

### WSL

- **Distro and networking:** Debian, NAT networking, with `localhostForwarding=true` and `networkingMode=mirrored` commented out in `%USERPROFILE%\.wslconfig`. systemd is enabled.
- **Caddy:** 2.11.9, from Caddy's apt repo.
  - **The service:** disabled and inactive. Its unit runs as `caddy`, with `AmbientCapabilities=CAP_NET_BIND_SERVICE` (so it doesn't need the `sysctl` that lets ordinary processes bind port 80 and up, which is set anyway), `Requires=network-online.target`, and `caddy run --environ`, which writes its environment to the journal: never put a secret in the unit's environment.
  - **Its data folder:** `/var/lib/caddy` exists (`drwx------ caddy`, dated 2026-10-28), so the service may already have run and made its certificate authority.
  - **The config file:** `/etc/caddy/Caddyfile` is a Debian conffile, so editing it makes `apt` ask about it on upgrade.
- **Name resolution:** only `curl` resolves `*.localhost` inside WSL, because it handles those names itself. `getent` and Node's `dns.lookup` fail (`ENOTFOUND`), as `/etc/nsswitch.conf` has `hosts: files dns`. So Node tools in WSL (e.g. httpyac) can't reach a `.localhost` name without a hosts-file entry or an NSS module, whichever side Caddy runs on.
- **Caddy's existing certificate authority:** `caddy run` uses the one in `~/.local/share/caddy/pki/authorities/local/`. Its root is trusted in the Linux store and the Windows user's store.
- **Home folder:** the user's home folder is `drwx------`, so the `caddy` user can't read project files.
- **`cloudflared`** isn't installed in WSL.

### Windows

- **Installed:**
  - Caddy 2.11.7, a per-user winget install (`%LOCALAPPDATA%\Microsoft\WinGet\Links\caddy.exe`);
  - `cloudflared` 2026.10.4 (`C:\Program Files (x86)\cloudflared\`), with no `%USERPROFILE%\.cloudflared` folder;
  - Node 22.
- **IIS holds ports 80 and 443.** HTTP.sys (PID 4) listens on `0.0.0.0` and `[::]` for both. W3SVC is running and starts automatically; WAS and HTTP are running and start manually. HTTP.sys's IP listen list (`netsh http show iplisten`) is empty.
- **IIS's configuration:** `applicationHost.config` is readable without admin rights. Its sites are bound by host name (`*:443:<name>.dev.example.net` with SNI, and `*:80:<name>`), plus a catch-all `*:80:` on "Default Web Site".
- **The hosts file** maps the IIS sites' names (`*.dev.example.net`) to `127.0.0.1`. It also maps a `.localhost` name that matches no IIS binding, so another project uses a `.localhost` name.

### Projects with a `Caddyfile` (both in WSL)

Two projects, not named here.

- **The first project:**
  - **How it starts:** a package script (`dev:caddy`) runs `next dev` on port 3000 and `caddy run` together; another (`dev:http`) runs the dev server alone.
  - **Its sites:** two, each with `header_up Host {upstream_hostport}`, and no global options:
    - `www.<project>.localhost` → `localhost:3000`;
    - `patterns.<project>.localhost` → `localhost:6006` (Storybook).
  - **Other uses of the names:** `next.config.js` lists the `www.` name in `allowedDevOrigins`, and `.httpyac.config.js` has a `caddy` environment. A third-party map only works on whitelisted hosts, so it's the best check that the name reaches the browser intact.
- **The second project:**
  - **How it starts:** Caddy is started by hand. The project uses pnpm, Wrangler and OpenNext.
  - **Global options:** `http_port`, `https_port`, `local_certs`, `auto_https disable_redirects`.
  - **Its sites:**
    - `dev.<project>.localhost` → `localhost:3000`;
    - `www.<project>.localhost` → `localhost:3001`, served over plain HTTP too;
    - `patterns.<project>.localhost` → `localhost:6006`.
  - **Something odd:** `file_server /app/public`, which only serves the single path `/app/public`.

### Caddy

- **`import`** takes a glob relative to its own file, and an empty glob isn't an error ([import](https://caddyserver.com/docs/caddyfile/directives/import)). An imported file can't have a global options block.
- **The admin API** listens on `localhost:2019` and lets anything that can reach it reconfigure Caddy ([global options](https://caddyserver.com/docs/caddyfile/options), `admin`).
- **Sites listen on every address** unless `bind` or `default_bind` says otherwise.

### Cloudflare Tunnel

- **One tunnel, several hostnames:** one remotely-managed tunnel routes several hostnames, each to its own local service.
- **Tokens:** `cloudflared tunnel run --token-file <file>` (or `TUNNEL_TOKEN_FILE`) keeps the token out of shell history and the process list ([run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/cloudflared-parameters/run-parameters/)).
- **The Host header:** the docs don't say whether the public Host header reaches the local service by default, so test it.
- **Quick tunnels** (`cloudflared tunnel --url …`) need no account. Each run gets a random `trycloudflare.com` name, and they allow at most 200 in-flight requests with no Server-Sent Events ([quick tunnels](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)).
- **Cloudflare Access** can put a login in front of a hostname and leave a path open with a Bypass policy ([policies](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)).

## The questions

### 1. Windows + WSL: which side runs Caddy?

- **A. Caddy in WSL**, the packaged systemd service.
  - The browser reaches it through WSL's localhost forwarding.
  - Its steps match macOS and Linux.
  - It only runs while WSL does: after a Windows restart, or once WSL stops, the names are down until something starts WSL.
- **B. Caddy on Windows**, a Windows service, forwarding to `127.0.0.1:<port>`.
  - It reaches dev servers in WSL through localhost forwarding and Windows dev servers directly.
  - It's the same as the Windows-only set-up, so there are two set-ups to document rather than three.
  - Caddy shares one trust store with the browser, and it runs whenever Windows does.
  - With NAT networking, nothing in WSL can reach it. Assess on paper whether WSL's mirrored networking mode would fix that, and what mirrored mode would change for A and for Docker Desktop. Don't change `.wslconfig`.

### 2. IIS

IIS holds ports 80 and 443 on every address, so it blocks both A and B: the browser's requests to `127.0.0.1:443` go to IIS, not to WSL's forwarding or a Windows Caddy. IIS is still used sometimes, and has been stopped whenever Caddy was needed. Other machines may have IIS too. Recommend the option that costs least to set up and undo:

1. **Switch by hand.** Stop one and start the other with a short command, so only one runs at a time. This is the fallback.
2. **Move HTTP.sys to another loopback address.** Add e.g. `127.0.0.2` to HTTP.sys's IP listen list (`netsh http add iplisten`), and point the IIS sites' hosts entries at it, which leaves `127.0.0.1` free.
   - The list applies to every HTTP.sys user on every port (WinRM, other apps), not just IIS ([netsh http](https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-http)).
   - Check whether HTTP.sys needs restarting for a change to take effect.
   - Browsers may resolve `.localhost` names to `127.0.0.1` whatever the hosts file says, so this can't move a `.localhost` IIS site.
3. **Caddy in front of IIS.** Caddy owns 80 and 443 and forwards IIS's names to IIS on other ports. Check what breaks, e.g. Windows authentication, or apps that expect a particular host or port.

### 3. Public names

Should the tunnel point at the dev server's port, or at Caddy? Pointing at Caddy keeps a project's routing in its sites file, with the public name as an `http://` site so Caddy doesn't try to get a public certificate. Under A, Windows' `cloudflared` reaching `localhost:80` hits IIS's catch-all binding.

## The set-up

**The same shape everywhere:** a top `Caddyfile` with global options and `import sites/*.caddy`, and a `sites` folder beside it with one file per project, holding a copy of that project's site blocks.

**Making the sites folder the user's:** one *(approval)* step creates the folder, owned by the user and readable by the service's account. After that, editing it needs no admin rights. So does `caddy reload --config <top Caddyfile>`, which posts the config to the admin API.

**Global options:** consider `default_bind 127.0.0.1 [::1]`, so dev servers aren't exposed to the network.

**Wildcard sites:** any wildcard site must only reach an allowed list of ports.

**Option A specifics:**
- **Files:** `/etc/caddy/Caddyfile` and `/etc/caddy/sites/`.
- **Trust:** `sudo caddy trust` for Linux. For Windows, fetch the root certificate from the admin API (`GET /pki/ca/local/certificates`, which `caddy trust` uses), so you never need to read `/var/lib/caddy`, then import it into the Windows user's store.

**Option B specifics:**
- **Location:** e.g. `C:\ProgramData\Caddy\`.
- **Binary:** use a machine-wide binary in a folder only administrators can write to, not the per-user winget one, since the user could overwrite that and it would run with the service's rights.
- **Account:** run the service as `NT AUTHORITY\LocalService` or a virtual account, not LocalSystem. Otherwise anything that reaches the admin API controls a process running as SYSTEM.
- **Start type:** create it with `start= demand` for the trial, so it doesn't race IIS at boot.
- **Upstreams:** use `127.0.0.1:<port>`, as WSL's forwarding may not cover `::1`.
- **Trust:** work out where `caddy trust` installs the root for a service running under another account.

**Copying sites files:** say whether keeping copies is workable, or what would be better (e.g. a small cross-platform script).

## Ground rules

- **Secrets:** never ask for, print, copy or write down a token, key, password or other secret. Don't open files that hold them: `.env.local`, `.env` files with real values, `~/.secrets`, credential stores, any `*.key` file, `cloudflared`'s `cert.pem` or credentials JSON. The user handles the tunnel token, keeps it in a file only they can read, and runs `cloudflared` with `--token-file`. To check whether an env file mentions a hostname, ask the user.
- **Git:** don't stage, commit, push, stash, switch branches, or run `git mv`/`git rm` in any repository. Leave changes in the working tree.
- **Live and shared systems:**
  - **Cloudflare:** the user does everything there (tunnels, hostnames, DNS, Access). Give one clear instruction, wait for them to say it's done, then verify from this machine.
  - **Everything else shared:** don't touch other cloud resources, shared environments or other people's data.
- **IIS:** before stopping anything, record the state and start type of W3SVC, WAS and HTTP, and restore them at the end of each test.
- **Ports:** never have two things wanting the same port at once. That means a project's `caddy run` (use the project's script for the dev server alone instead), WSL's Caddy service, Windows' Caddy service, and IIS.
- **Processes:** stop every dev server, Storybook, test server and tunnel you start once you've finished with it.
- **Undo:** keep a list of every change and how to reverse it.
- **End of the trial:** check that IIS is back as recorded, that no Caddy service is enabled or running unless the user chose that, and that no tunnel is running. Report what's still running and why.

## Steps

1. **Take stock (read-only).**
   - Re-check "What's already known", and correct it in the report.
   - Find other projects with a `Caddyfile` or `.localhost` names: `~/projects` in WSL, the user's repo folders on Windows (ask where they are; don't search all of `/mnt/c`), and whatever uses the `.localhost` name in the hosts file.
   - Check whether `/var/lib/caddy` already holds a certificate authority, if you can without `sudo`.
   - Work out the IIS options as far as you can without admin rights.
   - Draft the approval lists for steps 2 to 5 and show the user.
2. **Option A** *(approval)*.
   1. **IIS:** stop IIS for the test, as recorded.
   2. **Set up:** create the files and the sites folder, then `sudo systemctl enable --now caddy`. Check `systemctl status caddy` and `journalctl -u caddy`, and what Caddy listens on.
   3. **Trust:** trust the authority on both sides.
   4. **The first project:** start its dev server alone (`npm run dev:http`), and its Storybook. In a browser on Windows (Chrome or Edge):
      - both names load with no certificate warning;
      - the HMR websocket connects (ask the user for a trivial change if needed; you mustn't edit the project);
      - the third-party map loads.
   5. **From WSL:** check `curl` and httpyac (`-e caddy`) against both names.
   6. **Failure and restarts:**
      - stop the dev server and check for a 502, then start it again;
      - restart and reload Caddy a few times;
      - ask the user whether they'll restart WSL at a time that suits them, so you can check the names are down until WSL starts and come back by themselves when it does. Never run the shutdown yourself; if they'd rather not, skip it and say so in the report.
   7. **Clean up:** stop the service and restore IIS.
3. **Option B** *(approval)*.
   1. **IIS:** stop IIS for the test, as recorded.
   2. **Set up:** create the Windows service as above.
   3. **Browser checks:** repeat step 2's checks against the first project running in WSL.
   4. **A Windows dev server:** check a throwaway Node server on Windows (a `node -e` one-liner on a spare port, with no packages).
   5. **Restart:** restart the service (not Windows) and check the names come back.
   6. **Clean up:** stop the service and restore IIS.
4. **A name for any port**, in the option you recommend *(approval)*. Add a wildcard site routing by the port in the name (e.g. `3000.port.localhost` → `127.0.0.1:3000`), limited to an allowed list of ports that excludes 2019, from the first time it's loaded. Caddy allows placeholders in an upstream given without a scheme, as long as the result includes a port ([reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy), "Upstream addresses"). Check:
   - which placeholder gives the right label (check how labels are counted);
   - that the browser accepts the wildcard certificate;
   - that a port outside the list is refused.
5. **A public name** *(approval for each exposure, with what and for how long)*.
   1. **Quick tunnel:** with Windows' `cloudflared`, run one against a throwaway Node echo server, check it from outside, then stop it.
   2. **Named tunnel:** ask the user to create the tunnel and a `<person>-<app>.example.com` hostname, pointing at the echo server first. They run it with `--token-file`. Check HTTPS, the Host header the server receives, and that a POST arrives.
   3. **The first project:** only if the user agrees, point the hostname at its dev server. Say what works and what doesn't: Next may reject the public Host, as `allowedDevOrigins` lists only the local name, and a dev server shows error overlays and stack traces.
   4. **Access:** if the user wants it, they put Access in front of the hostname with one path left open. Check both.
   5. **Clean up:** stop the tunnel, and ask whether to keep the hostname and tunnel.
6. **The second project, on paper.** What its `Caddyfile` would need under the service: where its global options go, and whether `local_certs` and `auto_https disable_redirects` would affect other projects' sites; whether the plain-HTTP site still works; and what `file_server /app/public` is for. List the questions for whoever knows the project.
7. **Report**, in `docs/briefs/2026-11-11-caddy-service-trial-report.md` in this repo (a new file; leave it uncommitted):
   - **Recommendations:** A or B, the IIS option, and the tunnel's target, each with the reason.
   - **Each project:** works as is, works with changes (list them), or doesn't (list the gaps).
   - **A draft team guide for each set-up:**
     - installing Caddy and running it as a service;
     - the top `Caddyfile` and sites folder;
     - adding a project's sites and reloading;
     - trusting the certificate authority;
     - making `.localhost` names resolve for tools other than browsers;
     - installing `cloudflared` and running a tunnel from a token file;
     - IIS.

     Mark each step as tested here or taken from docs only. macOS will be docs only.
   - **Admin's guide:** setting up a team member's tunnel and hostnames and handing over the token, and when someone leaves, deleting their tunnel (or rotating its token) and hostnames.
   - **Projects:** what each project would change (e.g. a `dev:caddy` script, README and `AGENTS.md`), as a list for the user.
   - **Follow-up: recommended dotfiles changes for each OS,** as a list, not an edit. For example:
     - `Install-Caddy` no longer disabling the Linux service, or Caddy moving to Windows;
     - whether to keep `Enable-UnprivilegedLowPorts`;
     - installing and syncing the top `Caddyfile` and sites folder (and handling the Debian conffile);
     - trusting the authority;
     - installing `cloudflared`;
     - IIS.
   - **Everything you changed, and how to undo it.**
   - **What you couldn't check.**

## Addenda

- **Old Caddy roots in the Windows user's store.**
  - It holds two Caddy Local Authority roots. One is the authority `caddy run` uses in WSL. The other matches nothing in WSL: check whether it's the Windows Caddy's, or unused.
  - Once a service's authority replaces the one `caddy run` uses, the `caddy run` root and its Linux copy (`/usr/local/share/ca-certificates/Caddy_Local_Authority_-_*.crt`) become unused too.
  - Don't remove any during the trial. The report lists which can go, and the user decides.
