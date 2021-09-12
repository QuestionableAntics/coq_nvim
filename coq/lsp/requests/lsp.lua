(function(...)
  local cancels = {}

  local req = function(name, session_id, clients, callback)
    local n_clients, client_names = unpack(clients)

    if cancels[name] then
      pcall(cancels[name])
    end

    local payload = {
      method = name,
      uid = session_id,
      client = vim.NIL,
      done = true,
      reply = vim.NIL
    }

    if n_clients == 0 then
      COQlsp_notify(payload)
    else
      local on_resp_old = function(err, _, resp, client_id)
        n_clients = n_clients - 1
        payload.client = client_names[client_id] or vim.NIL
        payload.done = n_clients == 0
        payload.reply = resp or vim.NIL
        COQlsp_notify(payload)
      end

      local on_resp_new = function(err, resp, ctx)
        on_resp_old(err, nil, resp, ctx.client_id)
      end

      local on_resp = function(...)
        if type(({...})[2]) ~= "string" then
          on_resp_new(...)
        else
          on_resp_old(...)
        end
      end

      local ids, cancel = callback(on_resp)
      cancels[name] = cancel
    end
  end

  local clients = function()
    local n_clients = 0
    local client_names = {}
    for id, info in pairs(vim.lsp.buf_get_clients(0)) do
      n_clients = n_clients + 1
      client_names[id] = info.name
    end
    return n_clients, client_names
  end

  COQlsp_comp = function(name, session_id, pos)
    local row, col = unpack(pos)
    local position = {line = row, character = col}
    local text_doc = vim.lsp.util.make_text_document_params()
    local params = {
      position = position,
      textDocument = text_doc,
      context = {triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked}
    }
    req(
      name,
      session_id,
      {clients()},
      function(on_resp)
        return vim.lsp.buf_request(
          0,
          "textDocument/completion",
          params,
          on_resp
        )
      end
    )
  end

  COQlsp_preview = function(name, session_id, item)
    req(
      name,
      session_id,
      {clients()},
      function(on_resp)
        return vim.lsp.buf_request(0, "completionItem/resolve", item, on_resp)
      end
    )
  end

  COQlsp_third_party = function(name, session_id, pos)
    local sources = COQsources or {}
    req(
      name,
      session_id,
      {0, {}},
      function(on_resp)
        return {}, nil
      end
    )
  end
end)(...)
