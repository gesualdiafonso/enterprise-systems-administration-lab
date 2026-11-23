#
# nexora-ad.psd1 - Single source of truth for the NX-DC01 / nexora.local build.
# Values follow docs/networking/domain-structure.md and docs/networking/users-groups.md.
# ALL PEOPLE BELOW ARE FICTIONAL. No passwords are stored here: secrets are read
# from AWS SSM Parameter Store (SecureString) at run time - see Secrets.
#
@{
    Server = @{
        ComputerName = 'NX-DC01'
        TimeZone     = 'UTC'          # servers log in UTC; change with Get-TimeZone -ListAvailable
        PrivateIp    = '10.20.1.10'
        VpcResolver  = '10.20.0.2'    # Amazon-provided DNS (VPC base + 2)
    }

    Domain = @{
        DnsName         = 'nexora.local'
        NetBiosName     = 'NEXORA'
        DistinguishedName = 'DC=nexora,DC=local'
        ForestMode      = 'WinThreshold'   # Windows Server 2016 functional level
        DomainMode      = 'WinThreshold'
        RootOu          = 'Nexora'
        UpnSuffix       = 'nexora.local'
    }

    # SSM Parameter Store names (SecureString). Created from the workstation with
    # automation/aws-cli/set-lab-secrets.sh - never typed into scripts or Git.
    Secrets = @{
        AdministratorPassword = '/nexora/windows/administrator-password'
        DsrmPassword          = '/nexora/ad/dsrm-password'
        InitialUserPassword   = '/nexora/ad/initial-user-password'
        AdminAccountPassword  = '/nexora/ad/admin-account-password'
    }

    # Child OUs of OU=Nexora (order matters only for readability).
    OrganizationalUnits = @(
        @{ Name = 'Management';       Description = 'Executive team user accounts' }
        @{ Name = 'Administration';   Description = 'Office administration user accounts' }
        @{ Name = 'IT';               Description = 'IT staff user and admin accounts' }
        @{ Name = 'Finance';          Description = 'Finance staff user accounts' }
        @{ Name = 'Human Resources';  Description = 'HR staff user accounts' }
        @{ Name = 'Operations';       Description = 'Operations staff user accounts' }
        @{ Name = 'Service Accounts'; Description = 'Non-human identities' }
        @{ Name = 'Groups';           Description = 'Security group objects' }
        @{ Name = 'Servers';          Description = 'Member server computer objects' }
    )

    # Department OUs: delegated to GG-IT-HelpDesk for password reset / unlock.
    DepartmentOus = @('Management', 'Administration', 'IT', 'Finance', 'Human Resources', 'Operations')

    # All groups live in OU=Groups. MemberOf implements AGDLP nesting.
    Groups = @(
        @{ Name = 'GG-Nexora-AllStaff';      Scope = 'Global';      Description = 'Company-wide access (department groups nested)'; MemberOf = @() }
        @{ Name = 'GG-Management-Users';     Scope = 'Global';      Description = 'Management department role';     MemberOf = @('GG-Nexora-AllStaff') }
        @{ Name = 'GG-Administration-Users'; Scope = 'Global';      Description = 'Administration department role'; MemberOf = @('GG-Nexora-AllStaff') }
        @{ Name = 'GG-IT-Users';             Scope = 'Global';      Description = 'IT department role';             MemberOf = @('GG-Nexora-AllStaff') }
        @{ Name = 'GG-Finance-Users';        Scope = 'Global';      Description = 'Finance department role';        MemberOf = @('GG-Nexora-AllStaff', 'DL-FS-Finance-RW') }
        @{ Name = 'GG-HR-Users';             Scope = 'Global';      Description = 'HR department role';             MemberOf = @('GG-Nexora-AllStaff', 'DL-FS-HR-RW') }
        @{ Name = 'GG-Operations-Users';     Scope = 'Global';      Description = 'Operations department role';     MemberOf = @('GG-Nexora-AllStaff') }
        @{ Name = 'GG-IT-HelpDesk';          Scope = 'Global';      Description = 'Delegated password reset / unlock on department OUs'; MemberOf = @() }
        @{ Name = 'GG-IT-ServerAdmins';      Scope = 'Global';      Description = 'Local administrators on member servers (via GPO)';     MemberOf = @() }
        @{ Name = 'DL-FS-Finance-RW';        Scope = 'DomainLocal'; Description = 'Example resource permission: Finance share modify'; MemberOf = @() }
        @{ Name = 'DL-FS-HR-RW';             Scope = 'DomainLocal'; Description = 'Example resource permission: HR share modify';      MemberOf = @() }
    )

    # Standard users (fictional). Created disabled, grouped, then enabled with
    # the initial password and "must change password at next logon".
    Users = @(
        @{ GivenName = 'Helena';  Surname = 'Duarte';   Sam = 'hduarte';   Ou = 'Management';      Title = 'Chief Executive Officer'; Groups = @('GG-Management-Users') }
        @{ GivenName = 'Rui';     Surname = 'Matos';    Sam = 'rmatos';    Ou = 'Management';      Title = 'Chief Operating Officer'; Groups = @('GG-Management-Users') }
        @{ GivenName = 'Ana';     Surname = 'Lopes';    Sam = 'alopes';    Ou = 'IT';              Title = 'IT Manager';              Groups = @('GG-IT-Users') }
        @{ GivenName = 'Bruno';   Surname = 'Reis';     Sam = 'breis';     Ou = 'IT';              Title = 'Systems Administrator';   Groups = @('GG-IT-Users') }
        @{ GivenName = 'Carla';   Surname = 'Nunes';    Sam = 'cnunes';    Ou = 'IT';              Title = 'Help Desk Technician';    Groups = @('GG-IT-Users', 'GG-IT-HelpDesk') }
        @{ GivenName = 'Diana';   Surname = 'Faria';    Sam = 'dfaria';    Ou = 'Human Resources'; Title = 'HR Manager';              Groups = @('GG-HR-Users') }
        @{ GivenName = 'Eduardo'; Surname = 'Pinto';    Sam = 'epinto';    Ou = 'Human Resources'; Title = 'HR Specialist';           Groups = @('GG-HR-Users') }
        @{ GivenName = 'Filipe';  Surname = 'Sousa';    Sam = 'fsousa';    Ou = 'Operations';      Title = 'Operations Manager';      Groups = @('GG-Operations-Users') }
        @{ GivenName = 'Gabriela';Surname = 'Rocha';    Sam = 'grocha';    Ou = 'Operations';      Title = 'Operations Analyst';      Groups = @('GG-Operations-Users') }
        @{ GivenName = 'Hugo';    Surname = 'Teixeira'; Sam = 'hteixeira'; Ou = 'Operations';      Title = 'Logistics Coordinator';   Groups = @('GG-Operations-Users') }
        @{ GivenName = 'Ines';    Surname = 'Moreira';  Sam = 'imoreira';  Ou = 'Operations';      Title = 'Operations Assistant';    Groups = @('GG-Operations-Users') }
        @{ GivenName = 'Joana';   Surname = 'Carvalho'; Sam = 'jcarvalho'; Ou = 'Administration';  Title = 'Office Manager';          Groups = @('GG-Administration-Users') }
        @{ GivenName = 'Luis';    Surname = 'Martins';  Sam = 'lmartins';  Ou = 'Administration';  Title = 'Administrative Assistant';Groups = @('GG-Administration-Users') }
        @{ GivenName = 'Marta';   Surname = 'Gomes';    Sam = 'mgomes';    Ou = 'Finance';         Title = 'Finance Manager';         Groups = @('GG-Finance-Users') }
        @{ GivenName = 'Nuno';    Surname = 'Ferreira'; Sam = 'nferreira'; Ou = 'Finance';         Title = 'Accountant';              Groups = @('GG-Finance-Users') }
    )

    # Privileged identities: separate adm- accounts, never used for daily work.
    AdminAccounts = @(
        @{ Sam = 'adm-alopes'; Owner = 'alopes'; Ou = 'IT'; Groups = @('Domain Admins') }
        @{ Sam = 'adm-breis';  Owner = 'breis';  Ou = 'IT'; Groups = @('GG-IT-ServerAdmins') }
    )

    # Service accounts: long random password generated on the DC and never
    # displayed (reset it when a real service is configured), or gMSA later.
    ServiceAccounts = @(
        @{ Sam = 'svc-backup';     Owner = 'alopes'; Description = 'Backup jobs (Day 06) - owner: alopes' }
        @{ Sam = 'svc-monitoring'; Owner = 'breis';  Description = 'Monitoring queries (Day 06) - owner: breis' }
    )
}
