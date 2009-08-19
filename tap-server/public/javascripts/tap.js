var Tap = {
  App: {},
  Schema: {},
  Utils: {},
};

Tap.App = {
  /* Performs a tail update to target at the specified interval as long as 
   * checkbox is checked.  A tail update posts to action and inserts the
   * response at the bottom of target.
   */
  tail: function(action, checkbox, target, interval) {
    if($(checkbox).checked) {
      new Ajax.Request(action, {
        method: 'post',
        parameters: {
          pos: $(target).innerHTML.length
        },
        onSuccess: function(transport) {
          new Insertion.Bottom(target, transport.responseText);
        },
        onFailure: function(transport) { 
          alert(transport.responseText);
          $(checkbox).checked = false;
        }
      });
      
      var update = "Tap.App.tail('" + action + "', '" + checkbox + "', '" + target + "', " + interval + ");"
      setTimeout(update, interval);
    }
  },
  
  /* Performs a info update to target at the specified interval as long as 
   * checkbox is checked.  An info update posts to action and replaces the
   * inner html of target with the response.
   */
  info: function(action, checkbox, target, interval) {
    if($(checkbox).checked) {
      new Ajax.Request(action, {
        method: 'post',
        onSuccess: function(transport) {
          $(target).update(transport.responseText);
        },
        onFailure: function(transport) { 
          alert(transport.responseText);
          $(checkbox).checked = false;
        }
      });
      
      var update = "Tap.App.info('" + action + "', '" + checkbox + "', '" + target + "', " + interval + ");"
      setTimeout(update, interval);
    }
  },
};

Tap.Schema = {
  /* Collects schema parameters in the specified element (ie source and target
   * nodes that are checked, and the currently selected tasc, etc.).  These
   * parameters are used by the server to determine how to respond to actions
   * on a form.
   */
  parameters: function(id) {
    // Lookup elements
    element = document.getElementById(id)
    nodes = element.select('.node');
    manifests = element.select('.manifest');
    
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

    // Determine tascs selected by manifests
    tascs = []
    for (i=0;i<manifests.length;i++) {
      manifest = manifests[i];
      tascs.push(manifest.value);
      manifest.value = "";
    };
    
    parameters = {
      index: nodes.length,
      sources: sources,
      targets: targets,
      tascs: tascs
    };
    return parameters;
  },
  
  /* Performs an update to the specified element.  Update posts to action with
   * the Schema.parameters for element and inserts the response at the bottom
   * of the element.
   */
  update: function(id, action) {
    new Ajax.Updater(id, action, {
      method: 'post',
      insertion: Insertion.Bottom,
      parameters: Tap.Schema.parameters(id)
    });
  },
};

Tap.Utils = {
  select_all_by_name: function(name) {
    elements = document.getElementsByName(name);
    for (i=0;i<elements.length;i++) {
      element = elements[i];
      element.checked = true;
    };
  },
  
  deselect_all_by_name: function(name) {
    elements = document.getElementsByName(name);
    for (i=0;i<elements.length;i++) {
      element = elements[i];
      element.checked = false;
    };
  },
};