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
  
  /* Performs a tail update to target at the specified interval as long as 
   * checkbox is checked.  The target must have an integer position attribute,
   * indicating the end position of the last update.  Typically tail is called
   * when the checkbox changes value.
   *
   *   <div id='target' pos='0'></div>
   *   <input id='checkbox' type='checkbox' onchange="Tap.Run.tail('/path', 'checkbox', 'target', 1000);" >
   *
   */
  tail: function(path, checkbox, target, interval) {
    if($(checkbox).checked) {
      new Ajax.Request('/tail', {
        method: 'post',
        parameters: {
          path: path,
          pos: $(target).attributes.pos.value
        },
        onSuccess: function(transport) {
          var update = transport.responseText.evalJSON(true);
          new Insertion.Bottom(target, update.content);
          $(target).attributes.pos.value = update.pos;
        },
        onFailure: function() { 
          // a transport input may be specified to
          // print the error
          alert('Tail update failed...');
          $(checkbox).checked = false;
        }
      });
      
      var tail = "Tap.Run.tail('" + path + "', '" + checkbox + "', '" + target + "', " + interval + ");"
      setTimeout(tail, interval);
    }
  },
  
  // code smell
  toggle_preview: function(preview, target) {
    if($(preview).checked) $(target).action = "preview";
    else $(target).action="run";
  },
};
