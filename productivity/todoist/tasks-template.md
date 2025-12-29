# 📋 My Todoist Tasks

{{- if data }}
{{- $taskCount := len(data) }}

**Total Tasks:** {{ $taskCount }}

---

{{- range $index, $task := data }}

## □ {{ $task.content }}

{{- if $task.description }}
*{{ $task.description }}*
{{- end }}

{{- $priority := $task.priority }}
- **Priority**: {{ if priority == 4 }}🔴 High{{ else if priority == 3 }}🟡 Medium{{ else if priority == 2 }}🔵 Low{{ else }}⚪ None{{ end }}
{{- if $task.due }}
- **Due:** {{ $task.due.string }} {{- if $task.due.is_recurring }} 🔄 {{- end }}
{{- else }}
- **Due:** No due date
{{- end }}
{{- if $task.labels }}
- **Labels:** {{ range $i, $label := $task.labels }}{{ if $i }}, {{ end }}`{{ $label }}`{{ end }}
{{- end }}

{{- if $task.url }}
- [Open in Todoist]({{ $task.url }})
{{- end }}

{{- end }}

## 🎯 Quick Actions

- Add a new task: `flow add task`
- Refresh this view: `flow get tasks`

{{- else }}

## 🎉 No Tasks Found!

You're all caught up! No active tasks in your Todoist.

- Add a new task: `flow add task`

{{- end }}