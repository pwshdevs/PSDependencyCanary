---
external help file: PSDependencyCanary-help.xml
Module Name: PSDependencyCanary
online version:
schema: 2.0.0
---

# Clear-PSDependencyCanaryEnvironment

## SYNOPSIS
Removes a project's installed PowerShell dependencies before bootstrapping.

## SYNTAX

```
Clear-PSDependencyCanaryEnvironment [[-ProjectRoot] <String>] [[-ModulePath] <String[]>]
 [-AllowPreinstalledModules] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes every installed version of PSDepend, PSDependencyCanary, modules
declared in requirements.psd1, and modules declared by RequiredModules in the
project manifest.
Pester 3.x is preserved for Windows PowerShell compatibility.

Run this command in its own process or CI step.
The executing
PSDependencyCanary module remains loaded in memory until the process exits even
after its installed files have been removed.
The next process can then install
only the project's committed dependency pins.

## EXAMPLES

### EXAMPLE 1
```
Clear-PSDependencyCanaryEnvironment -ProjectRoot . -Confirm:$false
```

Cleans installed project dependencies before the committed bootstrap.

### EXAMPLE 2
```
Clear-PSDependencyCanaryEnvironment -ProjectRoot . -WhatIf
```

Shows which installed dependency directories would be removed.

## PARAMETERS

### -ProjectRoot
Root directory of the PowerShell module project.
Defaults to BHProjectPath
when available and otherwise to the current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModulePath
Module roots to clean.
Defaults to the current process PSModulePath entries.
This parameter is primarily useful for isolated validation.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AllowPreinstalledModules
Warn instead of failing when a protected or locked dependency cannot be removed.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
