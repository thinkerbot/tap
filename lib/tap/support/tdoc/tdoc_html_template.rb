require 'rdoc/generators/template/html/html'

#
# Add a template for documenting configurations.  Do so by inserting in the 
# template into the content regions used to template html.
# (see  'rdoc/generators/html_generator' line 864)
#
[
RDoc::Page::BODY, 
RDoc::Page::FILE_PAGE, 
RDoc::Page::METHOD_LIST].each do |content|
  
  # this substitution method duplicates the attribute template for configurations
  # (see rdoc\generators\template\html line 523)
  #
  #IF:attributes
  #    <div id="attribute-list">
  #      <h3 class="section-bar">Attributes</h3>
  #
  #      <div class="name-list">
  #        <table>
  #START:attributes
  #        <tr class="top-aligned-row context-row">
  #          <td class="context-item-name">%name%</td>
  #IF:rw
  #          <td class="context-item-value">&nbsp;[%rw%]&nbsp;</td>
  #ENDIF:rw
  #IFNOT:rw
  #          <td class="context-item-value">&nbsp;&nbsp;</td>
  #ENDIF:rw
  #          <td class="context-item-desc">%a_desc%</td>
  #        </tr>
  #END:attributes
  #        </table>
  #      </div>
  #    </div>
  #ENDIF:attributes
  #
  content.gsub!(/IF:attributes.*?ENDIF:attributes/m) do |match|
    match + "\n\n" + match.gsub(/attributes/, 'configurations').gsub(/Attributes/, 'Configurations')
  end
end
