extends PanelContainer

var margin
var margin_min
var margin_max
var graph = [5]
var graph_max = 20.0

func _draw():
	margin = max(size.x * 0.05, size.y*0.05)
	margin_min = Vector2(margin, margin)
	margin_max = size-margin_min
	if graph.size() > 1:
		draw_graph()
	draw_graph_bounds()

func draw_graph():
	var points = []
	var colors = []
	var i = 0
	var i_step = (margin_max.x-margin_min.x)/(graph.size()-1)
	for p in graph:
		if points.size()>1:
			points.append(points.back())
		var alpha = (p/graph_max)
		var x = margin_min.x+i
		var y = margin_max.y+(margin_min.y-margin_max.y)*alpha
		if not points.is_empty():
			if points.back().y < y:
				colors.append(Color.RED)
			else:
				colors.append(Color.GREEN)
		points.append(Vector2(x,y))
		i=i+i_step
	draw_multiline_colors(points, colors, 1.0, true)

func draw_graph_bounds():
	draw_line(margin_min, Vector2(margin_min.x, margin_max.y), Color.BLACK, 1.5, true)
	draw_line(Vector2(margin_min.x, margin_max.y), margin_max, Color.BLACK, 1.5, true)

func _on_timer_timeout():
	var jitter=randf()-0.49
	var chance_of_event = randf()
	if chance_of_event > 0.95:
		jitter+=randf()*2
	elif chance_of_event < 0.05:
		jitter-=randf()*2
	if graph.size()>8:
		var t = 0
		for i in range(4):
			t+=graph[graph.size()-3-i]
		jitter += ((t/4.0) - graph.back())/8
	if graph.back() > 0.75*graph_max:
		jitter-=randf()*0.3
	if graph.back() < 0.25*graph_max:
		jitter+=randf()*0.3
	graph.append(clamp(graph.back()+jitter,0,graph_max))
	queue_redraw()
