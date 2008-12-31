var Tap = {
  Run: {},
};

Tap.Run = {
  add: function(id) {
    // Determine the total number of nodes
    nodes = document.getElementById(id).getElementsByClassName('node');

    // Determine the indicies of source and target nodes
    sources = []
    targets = []
    for (i=0;i<nodes.length;i++) {
      source = nodes[i].getElementsByClassName('source_checkbox')[0];
      if(source.checked) {
        source.checked = false;
        sources.push(i);
      };
      
      target = nodes[i].getElementsByClassName('target_checkbox')[0];
      if(target.checked) {
        target.checked = false;
        targets.push(i);
      };
    };

    // Determine the currently selected tasc
    tasc_manifest = document.getElementById('tasc_manifest');
    tasc = tasc_manifest.value;
    tasc_manifest.value = ""
    
    new Ajax.Updater(id, '/run', { 
      method: 'post', 
      insertion: Insertion.Bottom,
      parameters: {
        action: 'add',
        index: nodes.length,
        sources: sources,
        targets: targets,
        tasc: tasc
      } 
    });
  },

  remove: function() {
    alert('remove');
  },

  update: function(id) {
    form = document.getElementById(id);
    form.method = "get";
    form.submit();
  },
};
