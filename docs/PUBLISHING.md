# Publish this project on GitHub

Repository: https://github.com/sirnaeemasghar/macOS-finder-address-bar

The repository already exists. The creation steps below are retained for forks or new copies; use the Future updates section for this project.

Suggested name: **macOS-finder-address-bar**

Suggested description: **A native macOS Finder address bar with clickable breadcrumbs, editable paths, and Terminal integration.**

## 1. Create an empty GitHub repository

1. Sign in and open https://github.com/new.
2. Choose your account as the owner and enter `macOS-finder-address-bar`.
3. Choose **Public** if you want everyone to see the code, or **Private** otherwise. MIT licensing does not require making the repository public.
4. Do not initialize it with a README, license, or .gitignore. Those files already exist locally.
5. Click **Create repository**, then copy its HTTPS repository URL.

Do not upload the whole working directory through the website: that can include generated apps and local diagnostics. Git respects the prepared .gitignore.

## 2. Publish from Terminal

Open Terminal in the project folder (the directory containing README.md, build.sh, and Sources). A local Git repository on branch `main` has already been initialized.

```sh
git status --short
git add .
git diff --cached --stat
git commit -m "Initial Finder Address Bar source"
```

If Git asks for your identity, configure it for this project and repeat the commit:

```sh
git config user.name "YOUR NAME"
git config user.email "YOUR GITHUB COMMIT EMAIL"
```

Use the GitHub-provided private commit email from your GitHub email settings if you do not want your personal email in public commits.

Replace the example URL below with the URL GitHub showed you:

```sh
git remote add origin https://github.com/sirnaeemasghar/macOS-finder-address-bar.git
git push -u origin main
```

If authentication is needed, GitHub CLI is an option:

```sh
gh auth login
```

Choose GitHub.com, HTTPS, and browser sign-in, and allow it to configure Git authentication if asked. Do not place tokens or passwords in repository URLs or source files.

Refresh the GitHub repository page. Confirm that README.md renders, LICENSE appears, and Sources, Tests, docs, build.sh, test.sh, Info.plist, and entitlements.plist are present. The .app, .build-cache, status.txt, and .DS_Store should be absent.

## Alternative: create from GitHub CLI

After the initial commit, you can create and push a repository directly instead of creating it on the website:

```sh
gh auth login
gh repo create macOS-finder-address-bar --private --source=. --remote=origin --push
```

Use `--public` instead of `--private` only if you intend to publish the code publicly. Do not run this alternative if you already created the repository in step 1.

## Future updates

```sh
git status
git add .
git diff --cached
git commit -m "Describe your change"
git push
```

## App releases

Keep compiled .app bundles out of source control. A later GitHub Release can attach a packaged build, but the current local build is ad-hoc signed and not notarized. Source publishing and distributing an installer are separate steps. Do not claim a stable signed release until it has been prepared and tested.

Official guide: https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
