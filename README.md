# deploy-widg
Deploy - Windows Installer DB Generator


## Overview

Windows Installer DB Generator (or WIDG) is a utility for creating dummy application MSI installers for testing purposes.
Based on 3 input parameters it will generate X number versions of an installer (e.g. 1.0.0/1.0.1), for Y number of Prodcuts, per Z number of Manufacturers.
The Manufactuers are based on ficticious corporations from films/tv and the product names are randomly generated strings beetwen 5 and 10 characters long.

The MSI's for each family of Product are major upgrade installers sharing the same UPGRADECODE meaning they will remove all previous versions of said product and prevent a downgrade.

The MSI's install a dummy payload of 3 files, a start menu shortcut and a desktop shortuct. The 3 files are a dummy .exe, .dll and .pdf. None of these files are usuable. They are simply text files that contain the product name and version so the files are not 0 byte.

## What WIDG is not
Is an MSI packaging utility. I've no plans to expand its use to create simple MSI packages from VS projects or other meta files.

## Prerequisites
Use a Windows 10 vm to generate packages. Will most likely work on Server 2012/2016 however I have not personally tested this.
### .Net
.NET 3.5 ia pre-requisite for Wix. Use the below command to add to Windows 10

```
Add-WindowsCapabality -Online -Name NetFX3~~~~
```

### Wix
Download and install the WIX Toolset http://wixtoolset.org/releases/

So far tested with v3.11.1.2318

Make sure "C:\Program Files (x86)\WiX Toolset v3.11\bin" is in your PATH environment variable.


## Staging Directory Structure

If not specified otherwise by using the -StagingRoot parameter the script will use c:\widgstaging to output staging files and msi's. A local file path should be used.

The structure is as follows:
```
<staging_root>/
├── <Manufacturer>/<Product>/<Version>
├── <Manufacturer>/<Product>/<Version>/source/helper.dll
├── <Manufacturer>/<Product>/<Version>/source/manual.pdf
├── <Manufacturer>/<Product>/<Version>/source/<product>Appl<Version>.exe
├── <Manufacturer>/<Product>/<Version>/msi
```

#### `<Manufacturer>/<Product>/<Version>`
e.g. MomCorp/Yqcids/1.0.0

#### `<Manufacturer>/<Product>/<Version>/source`
e.g. MomCorp/Yqcids/1.0.0/source

Used for dynamically created dummy non-zero byte app files (helper.dll, manual.pdf and .exe ) and the WIX toolset intermmediate .wks and .wixobj files.

#### `<Manufacturer>/<Product>/<Version>/msi`

Contains the output x86 and x64 .msi packages with the naming convention:
```
<name>-<arch>-<version>.msi

e.g.
Hdfsbg-x64-1.0.0.msi
Hdfsbg-x86-1.0.0.msi
```