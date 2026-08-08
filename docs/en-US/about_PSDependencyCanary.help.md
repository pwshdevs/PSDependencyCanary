# PSDependencyCanary

## about_PSDependencyCanary

# SHORT DESCRIPTION

Dependency update canary tasks for PSDepend, PowerShellBuild, and psake projects.

# LONG DESCRIPTION

PSDependencyCanary adds a shared Canary task to PowerShell module projects that
use PSDepend for dependency bootstrap, PowerShellBuild for build and test tasks,
and psake for task orchestration.

The task discovers newer PSGallery versions for modules declared in
requirements.psd1 and RequiredModules. It validates the unchanged project first,
updates the candidate declarations, bootstraps the candidate environment, and
runs the same Test task again. A failed candidate restores the original source
files.

PSDependencyCanary is designed as an add-on to this project workflow. It does not
provide a standalone dependency installer or a generic build runner.
Projects adopt the PSDepend, PowerShellBuild, and psake workflow rather than
supplying adapters for other dependency and build systems.

# EXAMPLES

Add the shared task to psakeFile.ps1:

    Task Canary -FromModule PSDependencyCanary -MinimumVersion '1.0.0'

Initialize the committed dependency environment and run Canary:

    ./build.ps1 -Task Init -Bootstrap
    ./build.ps1 -Task Canary

# NOTE

Every module declared in RequiredModules must also be pinned in
requirements.psd1 so PSDepend can reproduce both the baseline and candidate
environments.

# SEE ALSO

PowerShellBuild, psake, PSDepend

# KEYWORDS

dependency, canary, PowerShellBuild, psake, PSDepend
