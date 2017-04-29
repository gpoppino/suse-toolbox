# Scripts to simplify running some SUSE related commands

The idea behind this repository is to store many scripts that simplify
performing some tasks on SUSE Linux products.

## Scripts list

The following scripts are included, grouped by product or tool:

- [SLEPOS](https://www.suse.com/products/linux-point-of-service/):
    - **slepos_add_cash_register.sh**
    This script uses the command `posAdmin` to add a cash register
    (scCashRegister object tree) to LDAP using a role or in legacy mode.

    - **slepos_setup_branch.sh**
    This script also uses the command `posAdmin` to setup a branch
    (scLocation object tree) on LDAP.

- [SUSE Manager](https://www.suse.com/products/suse-manager/):
    - **suma_sync_repos.sh**
    Script to facilitate mirroring every channel that has been previously
    enabled on SUMA.
    - **suma_create_landscape_channels.sh**
    Script to create landscape channels as described in the scenario presented
    in the product's best practices.

- [Subscription Manager Tool](https://www.suse.com/products/subscription-management-tool/):
    - **smt_mirror_repo_by_name.sh**
    Script to mirror a SMT repository by name. Generally, if you need to mirror
    a specific repository you need to lookup its ID first and then run `smt mirror
    --repository ID`. This script simplifies these tasks, by enabling, looking up
    the repository ID and mirroring it.

- [Zypper](https://en.opensuse.org/Zypper):
   - **zypper_read_patches_info.sh**
   This script reads the information of every patch available and paginates it
   through `less`.


## Author

Geronimo Poppino <[gresco@gmail.com](mailto:gresco@gmail.com)>

