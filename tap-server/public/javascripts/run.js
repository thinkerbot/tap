var Tap = {
  Run: {},
};

Tap.Run = {
  parameters: function(id) {
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
    tasc_manifest.value = "";
    
    parameters = {
      index: nodes.length,
      sources: sources,
      targets: targets,
      tasc: tasc
    };
    return parameters;
  },
  
  add: function(id) {
    parameters = Tap.Run.parameters(id);
    parameters.action = 'add';
    
    new Ajax.Updater(id, '/run', { 
      method: 'post', 
      insertion: Insertion.Bottom,
      parameters: parameters 
    });
  },

  remove: function() {
    alert('remove');
  },
  
  /* Run compacts and renders (ie updates) a schema upon a get request. */
  update: function(id) {
    form = document.getElementById(id);
    form.method = "get";
    form.submit();
  },
  
  tail: function(path, update_id, id) {
    if($(update_id).checked) {
      new Ajax.Request('/tail', {
        method: 'post',
        parameters: {
          path: path,
          pos: $(id).attributes.pos.value
        },
        onSuccess: function(transport) {
          var json = transport.responseText.evalJSON(true);
          new Insertion.Bottom(id, json.content);
          $(id).attributes.pos.value = json.pos;
        },
        onFailure: function() { 
          alert('Something went wrong...') 
        }
      });
      
      var tail = "Tap.Run.tail('" + path + "', '" + update_id + "', '" + id + "');";
      setTimeout(tail, 1000);
    }
  },
};
