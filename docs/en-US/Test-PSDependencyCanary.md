---
external help file: PSDependencyCanary-help.xml
Module Name: PSDependencyCanary
online version:
schema: 2.0.0
---

# Test-PSDependencyCanary

## SYNOPSIS
Runs a module project's complete test build for a dependency candidate.

## SYNTAX

```
Test-PSDependencyCanary [[-ProjectRoot] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Executes the project's Test task in a clean child PowerShell process with
dependency bootstrap enabled, then verifies the expected module artifact.
This lower-level command is primarily useful for validating an already-created
candidate under another PowerShell edition.
Scheduled CI/CD should normally
invoke the shared Canary task.

## EXAMPLES

### EXAMPLE 1
```
Test-PSDependencyCanary -ProjectRoot .
```

Validates an already-created candidate in the current PowerShell edition and
verifies its staged module manifest.

## PARAMETERS

### -ProjectRoot
Root directory of the candidate project.

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
