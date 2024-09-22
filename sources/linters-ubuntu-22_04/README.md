# Image of Linters on Ubuntu 22.04 LTS

## Prepare

```bash
sudo usermod -a -G docker "${USER}"
```

## Manual launch

```bash
[DIR2CHECK=/home/user/git/repo-with-code] linters-ubuntu-22_04/check-dir.sh
```

The `DIR2CHECK` is a target directory for checking by linters. In case of absent, the `.` directory will be scanned recursively
