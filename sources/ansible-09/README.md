# Image of Ansible 9.9.0 on Ubuntu 22.04 LTS

## Prepare

```bash
sudo usermod -a -G docker "${USER}"
```

## Manual launch

```bash
ansible-09/ansible-docker.sh \
ansible-playbook site.yaml \
--diff -i inventory \
-t nftables -l xray
```

Note wish [load order](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#managing-inventory-variable-load-order) of inventory directories

## Linters on Python

```bash
[DIR2CHECK=/home/user/git/repo-with-code] ansible-09/check-dir.sh
```

The `DIR2CHECK` is a target directory for checking by linters. In case of absent, the `.` directory will be scanned recursively
