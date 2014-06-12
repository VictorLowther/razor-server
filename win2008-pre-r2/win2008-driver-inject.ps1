# -*- powershell -*-
# Inject drivers into a Windows 2008 non-R2 install.wim.
# This uses imagex and friends to do all the heavy lifting.
# It requires the install.wim to be present in the current directory.
# It also requires that the drivers be in a directory named "drivers"
# in the current directory

# These tools are from the Windows AIK.  We require that they exist.

$peimg = ' C:\Program Files\Windows AIK\Tools\PETools\peimg.exe'
$imagex = 'c:\Program Files\Windows AIK\Tools\amd64\imagex.exe'
$cwd = Get-Location
$temp = [Environment]::GetEnvironmentVariable("TEMP")

function test-administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (test-administrator)) {
    write-error @"
You must be running as administrator for this script to function.
Unfortunately, we can't reasonable elevate privileges ourselves
so you need to launch an administrator mode command shell and then
re-run this script yourself.
"@
    exit 1
}

if (-not (test-path $pkgmgr)) {
        write-error @"
Cannot find pkgmgr at ${pkgmgr}
Please install the Windows AIK to run this script.
"@
        exit 1
}

if (-not (test-path $imagex)) {
        write-error @"
Cannot find imagex at ${imagex}
Please install the Windows AIK to run this script
"@
        exit 1
}

$drivers = join-path $cwd 'drivers'

if (-not (test-path $drivers)) {
        write-error "No drivers directory in the current directory"
        exit 1
}

if (-not (test-path 'install.wim')) {
        write-error "No install.wim in the current directory"
        exit 1
}

# Dump info about all the images in XML format.
& "$imagex" '/INFO' '/XML' 'install.wim' > 'install.xml'

# Copy install.wim to install-updated.wim
cp 'install.wim' 'install-updated.wim'

# Parse the XML so that we can inject our drivers into all the images in the install.wim.
[xml]$images = Get-Content 'install.xml'

$images.WIM.IMAGE |foreach-object {
        $index = $_.INDEX
        $name = $_.NAME
        $mountpt = join-path $cwd.Path $name
        $scratch = join-path $cwd.Path 'scratch'
        if (test-path $mountpt) {
                write-error "${mountpt} exists.  Please remove it."
                exit 1
        }
        md $scratch
        md $mountpt
        & "$imagex" '/mountrw' 'install-updated.wim' "${index}" $mountpt
        Get-Childitem -recurse $drivers -include *.inf |foreach {
            $driverinf = $_
            & "$peimg" "/inf=${driverinf}" "${mountpt}"
        }
        & "$imagex" '/unmount' '/commit' $mountpt
        rm -r $mountpt
        rm -r $scratch
        # Zap the crap that imagex leaves lying around to keep it from filling the hard drive.
        Get-ChildItem $temp -include SSS* | foreach {
            rm -r $_
        }  
}