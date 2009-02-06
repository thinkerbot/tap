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
  
  /* Performs a tail update to target at the specified interval as long as 
   * checkbox is checked.  The target must have an integer position attribute,
   * indicating the end position of the last update.  Typically tail is called
   * when the checkbox changes value.
   *
   *   <div id='target' pos='0'></div>
   *   <input id='checkbox' type='checkbox' onchange="Tap.Run.tail('/path', 'checkbox', 'target', 1000);" >
   *
   */
  tail: function(url, checkbox, target, interval) {
    if($(checkbox).checked) {
      new Ajax.Request(url, {
        method: 'post',
        onSuccess: function(transport) {
          new Insertion.Bottom(target, transport.responseText);
        },
        onFailure: function(transport) { 
          alert(transport.responseText);
          $(checkbox).checked = false;
        }
      });
      
      var update = "Tap.Run.tail('" + url + "', '" + checkbox + "', '" + target + "', " + interval + ");"
      setTimeout(update, interval);
    }
  },
  
  update: function(url, checkbox, target, interval) {
    if($(checkbox).checked) {
      new Ajax.Request(url, {
        method: 'post',
        onSuccess: function(transport) {
          $(target).update(transport.responseText);
        },
        onFailure: function(transport) { 
          alert(transport.responseText);
          $(checkbox).checked = false;
        }
      });
      
      var update = "Tap.Run.update('" + url + "', '" + checkbox + "', '" + target + "', " + interval + ");"
      setTimeout(update, interval);
    }
  },
  
};
