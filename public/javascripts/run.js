var Tap = {
  Run: {},
};

Tap.Run = {
  add: function(id) {
    // Determine the total number of tasks
    tasks = document.getElementsByClassName('task');

    // Determine the indicies of source and target tasks
    sources = []
    targets = []
    for (i=0;i<tasks.length;i++) {
      source = task[i].getElementById('source[]' + i);
      if(source.checked) sources.push(i);
      
      target = task[i].getElementById('source_' + i);
      if(target.checked) targets.push(i);
    };

    // Determine the currently selected tasc
    tasc = document.getElementById('tasc').value;
    
    new Ajax.Updater(id, '/run', { 
      method: 'post', 
      insertion: Insertion.Bottom,
      parameters: {
        action: 'add',
        index: tasks.length,
        sources: sources,
        targets: targets,
        tasc: tasc
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
