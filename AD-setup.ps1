# Define the domain root
$domain = "DC=JoshRLab,DC=com"

# Define the base OU for the company
$companyOU = "OU=Company,$domain"

# Ensure the Company OU exists
if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$companyOU'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Company" -Path "DC=JoshRLab,DC=com" -ProtectedFromAccidentalDeletion $false
    Write-Host "Created OU: $companyOU"
} else {
    Write-Host "OU already exists: $companyOU"
}

# Define Departments (these will be used to create department OUs under the Company OU)
$departments = @("Executive", "HR", "IT", "Finance", "Sales", "Marketing", "Support", "Engineering")

foreach ($dept in $departments) {
    $deptOU = "OU=$dept,$companyOU"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$deptOU'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $dept -Path $companyOU -ProtectedFromAccidentalDeletion $false
        Write-Host "Created Department OU: $deptOU"
    } else {
        Write-Host "Department OU already exists: $deptOU"
    }
}

# Define Security Groups List
$SecurityGroups = @("Executive Access", "HR Restricted", "IT Admins", "Finance Restricted", "Sales Team", "Marketing Team", "Support Team", "Engineering Team")

# Create Security Groups under the Company OU if they don't exist
foreach ($group in $SecurityGroups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $companyOU -Description "$group security group"
        Write-Host "Created Security Group: $group"
    } else {
        Write-Host "Security Group already exists: $group"
    }
}

# Import users from CSV
$users = Import-Csv -Path ".\users.csv"

foreach ($user in $users) {
    # Use the Department field to determine the OU
    $ouPath = "OU=$($user.Department),$companyOU"
    $fullName = "$($user.FirstName) $($user.LastName)"
    $samAccountName = $user.Username
    $userPrincipalName = "$samAccountName@lab.local"

    # Check if user already exists
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue)) {
        # Create the AD user
        New-ADUser -Name $fullName `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -SamAccountName $samAccountName `
            -UserPrincipalName $userPrincipalName `
            -Path $ouPath `
            -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) `
            -Enabled $true `
            -Title $user.Title
        
        Write-Host "Created User: $fullName in OU: $ouPath"
    } else {
        Write-Host "User already exists: $fullName"
    }

    # Add user to the specified Security Group
    $securityGroup = $user.SecurityGroup
    if ($securityGroup -and (Get-ADGroup -Filter "Name -eq '$securityGroup'" -ErrorAction SilentlyContinue)) {
        Add-ADGroupMember -Identity $securityGroup -Members $samAccountName -ErrorAction SilentlyContinue
        Write-Host "Added $fullName to Security Group: $securityGroup"
    } else {
        Write-Host "Security Group not found for ${fullName}: $securityGroup"
    }
}