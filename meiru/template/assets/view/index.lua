
<div id="content">
    <div class="panel">
        <% if topics and #topics > 0 then %>
            <div class="inner no-padding">
                <%- partial('item', {collection = topics, as = 'topic'}) %>
            </div>
        <% else %>
            <div class="inner">
                <p>无话题</p>
            </div>
        <% end %>
    </div>
</div>
