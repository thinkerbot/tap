var Tap = {
  Run: {},
};

Tap.Run = {
  add: function(id) {
    // Determine the total number of tasks
    tasks = document.getElementsByClassName('task');

    // Determine the indicies of selected tasks
    selected_tasks = []
    // for (i=0;i<tasks.length;i++) {
    //   selector = task[i]
    //   // if(selector.checked) selected_tasks.push(selector.value);
    // };
    
    // Determine the currently selected tasc
    selected_task = document.getElementById('manifest').value;
    if (selected_task != "") selected_tasks.push(selected_task);
    
    new Ajax.Updater(id, '/run', { 
      method: 'post', 
      insertion: Insertion.Bottom,
      parameters: {
        action: 'add',
        index: tasks.length,
        selected_tasks: selected_tasks
      } 
    });
  },

  remove: function() {
    alert('remove');
  },

  update: function() {
    alert('update');
  },
};
