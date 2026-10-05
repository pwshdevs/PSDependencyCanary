---
external help file: PSDependencyCanary-help.xml
Module Name: PSDependencyCanary
online version:
schema: 2.0.0
---

# Update-PSDependencyCanary

## SYNOPSIS
Updates a module project's dependencies only after baseline and candidate tests pass.

## SYNTAX

```
Update-PSDependencyCanary [[-ProjectRoot] <String>] [[-ModuleManifestPath] <String>]
 [[-RequirementsPath] <String>] [[-ChangelogPath] <String>] [-SkipChangelog]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Finds newer PSGallery versions for dependencies declared in requirements.psd1
and RequiredModules.
When updates are available, the unchanged project must pass
its Test build task before any files are edited.
The complete candidate is then applied temporarily and tested again with
dependency bootstrap enabled.
Failed candidates are restored.
Build-only updates do not change the module version; a RequiredModules
update patch-bumps the shipped module manifest and updates the changelog.
The applying behavior of this lower-level API is used by the shared Canary task;
invoke that task to create dependency candidates.

## EXAMPLES

### EXAMPLE 1
```
Update-PSDependencyCanary -ProjectRoot . -WhatIf
```

Reports available dependency changes without bootstrapping, testing, or editing.

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

### -ModuleManifestPath
Optional module manifest path.
Conventional src layouts are auto-discovered.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RequirementsPath
PSDepend build requirements file.
Defaults to requirements.psd1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ChangelogPath
Keep a Changelog document updated when RequiredModules changes.
Defaults to
CHANGELOG.md.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipChangelog
Patch-bump runtime dependency candidates without reading or updating a changelog.

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
