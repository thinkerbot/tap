var Run = {
	add: function() {
		// Determine the total number of tasks
		selectors = document.getElementsByClassName('selector');
		n_tasks = selectors.length;
		
		// Determine the indicies of selected tasks
		selected_tasks = []
		for (i=0;i<selectors.length;i++) {
			selector = selectors[i]
		  if(selector.checked) selected_tasks.push(selector.value);
		};
		
		// Determine the currently selected tasc
		tasc = document.getElementById('tasc_selector').value;
		
		new Ajax.Updater('tasks', '/run', { 
			method: 'get', 
			insertion: Insertion.Bottom,
		  parameters: {tasc: tasc, n_tasks: n_tasks, selected_tasks: selected_tasks} 
		});
  },

	remove: function() {
		alert('remove');
  },


};
