defmodule Zaryn.Contracts.Interpreter do
  @moduledoc false

  alias Crontab.CronExpression.Parser, as: CronParser

  alias __MODULE__.Library
  alias __MODULE__.TransactionStatements

  alias Zaryn.Contracts.Contract
  alias Zaryn.Contracts.Contract.Conditions

  alias Zaryn.SharedSecrets

  alias Zaryn.TransactionChain.Transaction

  @library_functions_names Library.__info__(:functions)
                           |> Enum.map(&Atom.to_string(elem(&1, 0)))

  @transaction_statements_functions_names TransactionStatements.__info__(:functions)
                                          |> Enum.map(&Atom.to_string(elem(&1, 0)))

  @transaction_fields [
    "address",
    "type",
    "timestamp",
    "previous_signature",
    "previous_public_key",
    "origin_signature",
    "content",
    "keys",
    "code",
    "zaryn_ledger",
    "nft_ledger",
    "zaryn_transfers",
    "nft_transfers",
    "authorized_keys",
    "secret",
    "recipients"
  ]

  @condition_fields Conditions.__struct__()
                    |> Map.keys()
                    |> Enum.reject(&(&1 == :__struct__))
                    |> Enum.map(&Atom.to_string/1)

  @transaction_types Transaction.types() |> Enum.map(&Atom.to_string/1)
  @origin_families SharedSecrets.list_origin_families() |> Enum.map(&Atom.to_string/1)

  @doc ~S"""
  Parse a smart contract code and return the filtered AST representation.

  The parser uses a whitelist of instructions, the rest will be rejected

  ## Examples

      iex> Interpreter.parse("
      ...>    condition transaction: [
      ...>      content: regex_match?(\"^Mr.Y|Mr.X{1}$\"),
      ...>      origin_family: biometric
      ...>    ]
      ...>
      ...>    condition inherit: [
      ...>       content: regex_match?(\"hello\")
      ...>    ]
      ...>
      ...>    condition oracle: [
      ...>      content: json_path_extract(\"$.zaryn.eur\") > 1
      ...>    ]
      ...>
      ...>    actions triggered_by: datetime, at: 1603270603 do
      ...>      new_content = \"Sent #{10.04}\"
      ...>      set_type transfer
      ...>      set_content new_content
      ...>      add_zaryn_transfer to: \"22368B50D3B2976787CFCC27508A8E8C67483219825F998FC9D6908D54D0FE10\", amount: 10.04
      ...>    end
      ...>
      ...>    actions triggered_by: oracle do
      ...>      set_content \"zaryn price changed\"
      ...>    end
      ...> ")
      {:ok,
        %Contract{
          conditions: %{
             inherit: %Zaryn.Contracts.Contract.Conditions{
                content: {
                      :==,
                      [line: 7],
                      [
                        true,
                        {{:., [line: 7], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library], [:Library]}, :regex_match?]}, [line: 7], [{:get_in, [line: 7], [{:scope, [line: 7], nil}, ["next", "content"]]}, "hello"]}
                      ]
                },
                authorized_keys: nil,
                code: nil,
                nft_transfers: nil,
                origin_family: :all,
                previous_public_key: nil,
                type: nil,
                zaryn_transfers: nil
             },
            oracle: %Zaryn.Contracts.Contract.Conditions{
                 content: {
                      :>,
                      [line: 11],
                      [
                        {
                          :==,
                          [line: 11],
                          [
                            {:get_in, [line: 11], [{:scope, [line: 11], nil}, ["transaction", "content"]]},
                            {{:., [line: 11], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library], [:Library]}, :json_path_extract]}, [line: 11], [{:get_in, [line: 11], [{:scope, [line: 11], nil}, ["transaction", "content"]]}, "$.zaryn.eur"]}
                          ]
                        },
                        1
                      ]
                  },
                 authorized_keys: nil,
                 code: nil,
                 nft_transfers: nil,
                 origin_family: :all,
                 previous_public_key: nil,
                 type: nil,
                 zaryn_transfers: nil
             },
             transaction: %Zaryn.Contracts.Contract.Conditions{
                 content: {
                      :==,
                      [line: 2],
                      [
                        true,
                        {{:., [line: 2], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library], [:Library]}, :regex_match?]}, [line: 2], [{:get_in, [line: 2], [{:scope, [line: 2], nil}, ["transaction", "content"]]}, "^Mr.Y|Mr.X{1}$"]}
                      ]
                 },
                 origin_family: :biometric,
                 authorized_keys: nil,
                 code: nil,
                 nft_transfers: nil,
                 previous_public_key: nil,
                 type: nil,
                 zaryn_transfers: nil
             }
         },
         constants: %Constants{},
         next_transaction: %Transaction{ data: %TransactionData{}},
         triggers: [
           %Trigger{
             actions: {:__block__, [],
              [
                {:=, [line: 15], [{:scope, [line: 15], nil}, {{:., [line: 15], [{:__aliases__, [line: 15], [:Map]}, :put]}, [line: 15], [{:scope, [line: 15], nil}, "new_content", "Sent 10.04"]}]},
                {
                  :=,
                  [line: 16],
                  [
                    {:scope, [line: 16], nil},
                    {:update_in, [line: 16], [{:scope, [line: 16], nil}, ["contract"], {:&, [line: 16], [{{:., [line: 16], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_type]}, [line: 16], [{:&, [line: 16], [1]}, "transfer"]}]}]}
                  ]
                },
                {
                  :=,
                  [line: 17],
                  [
                    {:scope, [line: 17], nil},
                    {:update_in, [line: 17], [{:scope, [line: 17], nil}, ["contract"], {:&, [line: 17], [{{:., [line: 17], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_content]}, [line: 17], [{:&, [line: 17], [1]}, {:get_in, [line: 17], [{:scope, [line: 17], nil}, ["new_content"]]}]}]}]}
                  ]
                },
                {
                  :=,
                  [line: 18],
                  [
                    {:scope, [line: 18], nil},
                    {:update_in, [line: 18], [{:scope, [line: 18], nil}, ["contract"], {:&, [line: 18], [{{:., [line: 18], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :add_zaryn_transfer]}, [line: 18], [{:&, [line: 18], [1]}, [{"to", <<34, 54, 139, 80, 211, 178, 151, 103, 135, 207, 204, 39, 80, 138, 142, 140, 103, 72, 50, 25, 130, 95, 153, 143, 201, 214, 144, 141, 84, 208, 254, 16>>}, {"amount", 10.04}]]}]}]}
                  ]
                }
              ]},
             opts: [at: ~U[2020-10-21 08:56:43Z]],
             type: :datetime
           },
           %Trigger{actions: {
              :=,
              [line: 22],
              [
                {:scope, [line: 22], nil},
                {:update_in, [line: 22], [{:scope, [line: 22], nil}, ["contract"], {:&, [line: 22], [{{:., [line: 22], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_content]}, [line: 22], [{:&, [line: 22], [1]}, "zaryn price changed"]}]}]}
              ]
           }, opts: [], type: :oracle}
         ]
        }
      }

  #   Returns an error when there are invalid trigger options

  #     iex> Interpreter.parse("
  #     ...>    actions triggered_by: datetime, at: 0000000 do
  #     ...>    end
  #     ...> ")
  #     {:error, "invalid trigger - invalid datetime - arguments at:0 - L1"}

  #   Returns an error when a invalid term is provided

  #     iex> Interpreter.parse("
  #     ...>    actions do
  #     ...>       System.user_home
  #     ...>    end
  #     ...> ")
  #     {:error, "unexpected token - System - L2"}
  """
  @spec parse(code :: binary()) :: {:ok, Contract.t()} | {:error, reason :: binary()}
  def parse(code) when is_binary(code) do
    with {:ok, ast} <-
           Code.string_to_quoted(String.trim(code),
             static_atoms_encoder: &atom_encoder/2
           ),
         {_, {:ok, %{contract: contract}}} <-
           Macro.traverse(
             ast,
             {:ok, %{scope: :root, contract: %Contract{}}},
             &prewalk/2,
             &postwalk/2
           ) do
      {:ok, contract}
    else
      {_node, {:error, reason}} ->
        {:error, format_error_reason(reason)}

      {:error, reason} ->
        {:error, format_error_reason(reason)}
    end
  catch
    {{:error, reason}, {:., metadata, [{:__aliases__, _, atom: cause}, _]}} ->
      {:error, format_error_reason({metadata, reason, cause})}

    {{:error, :unexpected_token}, {:atom, key}} ->
      {:error, format_error_reason({[], "unexpected_token", key})}

    {{:error, :unexpected_token}, {{:atom, key}, metadata, _}} ->
      {:error, format_error_reason({metadata, "unexpected_token", key})}

    {:error, reason = {_metadata, _message, _cause}} ->
      {:error, format_error_reason(reason)}
  end

  defp atom_encoder(atom, _) do
    if atom in ["if"] do
      {:ok, String.to_atom(atom)}
    else
      {:ok, {:atom, atom}}
    end
  end

  defp format_error_reason({metadata, message, cause}) do
    message =
      if message == "unexpected token: " do
        "unexpected token"
      else
        message
      end

    line = Keyword.get(metadata, :line)
    column = Keyword.get(metadata, :column)

    metadata_string = "L#{line}"

    metadata_string =
      if column == nil do
        metadata_string
      else
        metadata_string <> ":C#{column}"
      end

    message =
      if is_atom(message) do
        message |> Atom.to_string() |> String.replace("_", " ")
      else
        message
      end

    "#{message} - #{cause} - #{metadata_string}"
  end

  # Whitelist operators
  defp prewalk(node = {:+, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:-, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:/, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:*, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:>, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:<, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:>=, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:<=, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:|>, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:==, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  # Allow variable assignation inside the actions
  defp prewalk(node = {:=, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  # Whitelist the use of doted statement
  defp prewalk(node = {{:., _, [{_, _, _}, _]}, _, []}, acc = {:ok, %{scope: scope}})
       when scope != :root,
       do: {node, acc}

  # # Whitelist the definition of globals in the root
  # defp prewalk(node = {:@, _, [{key, _, [val]}]}, acc = {:ok, :root})
  #      when is_atom(key) and not is_nil(val),
  #      do: {node, acc}

  # # Whitelist the use of globals
  # defp prewalk(node = {:@, _, [{key, _, nil}]}, acc = {:ok, _}) when is_atom(key),
  #   do: {node, acc}

  # Whitelist conditional oeprators
  defp prewalk(node = {:if, _, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = {:else, _}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = [do: _, else: _], acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  defp prewalk(node = :else, acc = {:ok, %{scope: scope}}) when scope != :root, do: {node, acc}

  defp prewalk(node = {:and, _, _}, acc = {:ok, _}), do: {node, acc}
  defp prewalk(node = {:or, _, _}, acc = {:ok, _}), do: {node, acc}

  # Whitelist the in operation
  defp prewalk(node = {:in, _, [_, _]}, acc = {:ok, _}), do: {node, acc}

  # Whitelist maps
  defp prewalk(node = {:%{}, _, fields}, acc = {:ok, _}) when is_list(fields), do: {node, acc}

  defp prewalk(node = {key, _val}, acc) when is_binary(key) do
    {node, acc}
  end

  # Whitelist the multiline
  defp prewalk(node = {{:__block__, _, _}}, acc = {:ok, _}) do
    {node, acc}
  end

  defp prewalk(node = {:__block__, _, _}, acc = {:ok, _}) do
    {node, acc}
  end

  # Whitelist custom atom
  defp prewalk(node = :atom, acc), do: {node, acc}

  # Whitelist the actions DSL
  defp prewalk(node = {{:atom, "actions"}, _, _}, {:ok, acc = %{scope: :root}}) do
    {node, {:ok, %{acc | scope: :actions}}}
  end

  # Whitelist the triggered_by DSL in the actions
  defp prewalk(
         node = [
           {{:atom, "triggered_by"}, {{:atom, trigger_type}, meta = [line: _], _}} | trigger_opts
         ],
         acc = {:ok, %{scope: :actions}}
       )
       when trigger_type in ["datetime", "interval", "transaction", "oracle"] do
    case valid_trigger_opts(trigger_type, trigger_opts) do
      :ok ->
        {node, acc}

      {:error, reason} ->
        params = Enum.map(trigger_opts, fn {{:atom, k}, v} -> "#{k}:#{v}" end) |> Enum.join(", ")
        {node, {:error, {meta, "invalid trigger - #{reason}", "arguments #{params}"}}}
    end
  end

  defp prewalk(
         node = {{:atom, "triggered_by"}, {{:atom, trigger_type}, _, _}},
         acc = {:ok, %{scope: :actions}}
       )
       when trigger_type in ["datetime", "interval", "transaction", "oracle"],
       do: {node, acc}

  defp prewalk(node = {:atom, trigger_type}, acc = {:ok, %{scope: :actions}})
       when trigger_type in ["datetime", "interval", "transaction", "oracle"],
       do: {node, acc}

  # Whitelist triggers 'at' argument
  defp prewalk(node = {{:atom, "at"}, _arg}, acc = {:ok, %{scope: :actions}}), do: {node, acc}

  # Whitelist the condition DSL
  defp prewalk(
         node = {{:atom, "condition"}, _, [{{:atom, condition_name}, [_]}]},
         {:ok, acc = %{scope: :root}}
       )
       when condition_name in ["inherit", "transaction", "oracle"] do
    {node, {:ok, %{acc | scope: :condition}}}
  end

  defp prewalk(node = [{{:atom, condition}, [_ | _]}], acc = {:ok, %{scope: :condition}})
       when condition in ["inherit", "transaction", "oracle"] do
    {node, acc}
  end

  defp prewalk(
         node = {{:atom, "condition"}, _, [[{{:atom, condition_name}, _}]]},
         {:ok, acc = %{scope: :root}}
       )
       when condition_name in ["inherit", "transaction", "oracle"] do
    {node, {:ok, %{acc | scope: :condition}}}
  end

  defp prewalk(node = [{{:atom, _}, _} | _], acc = {:ok, %{scope: :condition}}) do
    {node, acc}
  end

  defp prewalk(node = {{:atom, condition_name}, _}, acc = {:ok, %{scope: :condition}})
       when condition_name in ["inherit", "transaction", "oracle"] do
    {node, acc}
  end

  defp prewalk(node = {:atom, condition_name}, acc = {:ok, %{scope: :condition}})
       when condition_name in ["inherit", "transaction", "oracle"],
       do: {node, acc}

  defp prewalk(node = {:atom, field_name}, acc = {:ok, %{scope: :condition}})
       when field_name in @condition_fields,
       do: {node, acc}

  defp prewalk(
         node = {:., _, [{{:atom, transaction_ref}, _, nil}, {:atom, type}]},
         acc = {:ok, %{scope: :condition}}
       )
       when transaction_ref in ["next", "previous", "transaction", "contract"] and
              type in @transaction_fields do
    {node, acc}
  end

  # Whitelist Access key based with brackets, ie. zaryn_transfers["Alice"]
  defp prewalk(
         node =
           {{:., metadata, [Access, :get]}, _,
            [{{:., [_], [{{:atom, subject}, [_], nil}, {:atom, field}]}, _, []}, key]},
         acc = {:ok, scope: scope}
       )
       when scope != :root and
              subject in [:contract, :prev, :next, :transaction] and
              field in @transaction_fields and is_binary(key) do
    case Base.decode16(key, case: :mixed) do
      {:ok, _} ->
        {node, acc}

      _ ->
        {node, {:error, {metadata, "unexpected token", ""}}}
    end
  end

  # Whitelist the use of list
  defp prewalk(node = [{{:atom, _}, _, nil} | _], acc = {:ok, %{scope: scope}})
       when scope != :root do
    {node, acc}
  end

  # Whitelist access to map field
  defp prewalk(node = {:., _, [Access, :get]}, acc = {:ok, %{scope: scope}}) when scope != :root,
    do: {node, acc}

  # Whitelist condition fields

  # Whitelist the origin family condition
  defp prewalk(
         node = {{:atom, "origin_family"}, {{:atom, family}, metadata, nil}},
         acc = {:ok, %{scope: :condition}}
       ) do
    if family in @origin_families do
      {node, acc}
    else
      {node, {:error, metadata, "unexpected token"}, "invalid origin family"}
    end
  end

  defp prewalk(node = {:atom, origin_family}, acc = {:ok, %{scope: :condition}})
       when origin_family in @origin_families,
       do: {node, acc}

  # Whitelist the transaction type condition
  defp prewalk(
         node = {{:atom, "type"}, {{:atom, type}, metadata, nil}},
         acc = {:ok, %{scope: :condition}}
       ) do
    if type in @transaction_types do
      {node, acc}
    else
      {node, {:error, metadata, "unexpected token"}, "invalid transaction type"}
    end
  end

  defp prewalk(
         node = {{:atom, field}, _},
         acc = {:ok, %{scope: :condition}}
       )
       when field in @condition_fields do
    {node, acc}
  end

  # Whitelist the use of transaction and contract fields in the actions
  defp prewalk(
         node = {:., _, [{{:atom, key}, _, _}, {:atom, field}]},
         acc = {:ok, %{scope: :actions}}
       )
       when key in ["contract", "transaction"] and field in @transaction_fields do
    {node, acc}
  end

  defp prewalk(
         node = {:., _, [{{:atom, key}, _, _}, {:atom, field}]},
         acc = {:ok, %{scope: :condition}}
       )
       when key in ["contract", "transaction"] and field in @transaction_fields do
    {node, acc}
  end

  defp prewalk(
         node = {{:atom, field}, [line: _], _},
         acc = {:ok, %{scope: {:function, _}}}
       )
       when field in @transaction_fields do
    {node, acc}
  end

  # Whitelist the size/1 function
  defp prewalk(
         node = {{:atom, "size"}, _, [_data]},
         acc = {:ok, %{scope: scope}}
       )
       when scope != :root do
    {node, acc}
  end

  # Whitelist the hash/1 function
  defp prewalk(node = {{:atom, "hash"}, _, [_data]}, acc = {:ok, %{scope: scope}})
       when scope != :root,
       do: {node, acc}

  # Whitelist the regex_match?/2 function
  defp prewalk(
         node = {{:atom, "regex_match?"}, _, [_input, _search]},
         acc = {:ok, %{scope: scope}}
       )
       when scope != :root,
       do: {node, acc}

  # Whitelist the regex_extract/2 function
  defp prewalk(
         node = {{:atom, "regex_extract"}, _, [_input, _search]},
         acc = {:ok, %{scope: scope}}
       )
       when scope != :root,
       do: {node, acc}

  # Whitelist the json_path_extract/2 function
  defp prewalk(
         node = {{:atom, "json_path_extract"}, _, [_input, _search]},
         acc = {:ok, %{scope: scope}}
       )
       when scope != :root,
       do: {node, acc}

  # Whitelist the json_path_match?/2 function
  defp prewalk(
         node = {{:atom, "json_path_match?"}, _, [_input, _search]},
         acc = {:ok, %{scope: scope}}
       )
       when scope != :root,
       do: {node, acc}

  # Whitelist the regex_match?/1 function in the condition
  defp prewalk(
         node = {{:atom, "regex_match?"}, _, [_search]},
         acc = {:ok, %{scope: :condition}}
       ) do
    {node, acc}
  end

  # Whitelist the json_path_extract/1 function in the condition
  defp prewalk(
         node = {{:atom, "json_path_extract"}, _, [_search]},
         acc = {:ok, %{scope: :condition}}
       ) do
    {node, acc}
  end

  # Whitelist the json_path_match?/1 function in the condition
  defp prewalk(
         node = {{:atom, "json_path_match?"}, _, [_search]},
         acc = {:ok, %{scope: :condition}}
       ) do
    {node, acc}
  end

  # Whitelist the hash/0 function in the condition
  defp prewalk(
         node = {{:atom, "hash"}, _, []},
         acc = {:ok, %{scope: :condition}}
       ) do
    {node, acc}
  end

  # Whitelist the in?/1 function in the condition
  defp prewalk(
         node = {{:atom, "in?"}, _, [_data]},
         acc = {:ok, %{scope: :condition}}
       ) do
    {node, acc}
  end

  # Whitelist the size/0 function in the condition
  defp prewalk(node = {{:atom, "size"}, _, []}, acc = {:ok, %{scope: :condition}}),
    do: {node, acc}

  # Whitelist the used of functions in the actions
  defp prewalk(node = {{:atom, fun_name}, _, _}, {:ok, acc = %{scope: :actions}})
       when fun_name in @transaction_statements_functions_names,
       do: {node, {:ok, %{acc | scope: {:function, fun_name, :actions}}}}

  defp prewalk(
         node = [{{:atom, _variable_name}, _, nil}],
         acc = {:ok, %{scope: {:function, "set_content", :actions}}}
       ) do
    {node, acc}
  end

  # Whitelist the add_zaryn_transfer argument list
  defp prewalk(
         node = [{{:atom, "to"}, _to}, {{:atom, "amount"}, _amount}],
         acc = {:ok, %{scope: {:function, "add_zaryn_transfer", :actions}}}
       ) do
    {node, acc}
  end

  defp prewalk(
         node = {{:atom, arg}, _},
         acc = {:ok, %{scope: {:function, "add_zaryn_transfer", :actions}}}
       )
       when arg in ["to", "amount"],
       do: {node, acc}

  # Whitelist the add_nft_tranfser argument list
  defp prewalk(
         node = [
           {{:atom, "to"}, _to},
           {{:atom, "amount"}, _amount},
           {{:atom, "nft"}, _nft_address}
         ],
         acc = {:ok, %{scope: {:function, "add_nft_transfer", :actions}}}
       ) do
    {node, acc}
  end

  defp prewalk(
         node = {{:atom, arg}, _},
         acc = {:ok, %{scope: {:function, "add_nft_transfer", :actions}}}
       )
       when arg in ["to", "amount", "nft"],
       do: {node, acc}

  # Whitelist the add_authorized_key argument list
  defp prewalk(
         node = [
           {{:atom, "public_key"}, _public_key},
           {{:atom, "encrypted_secret_key"}, _encrypted_secret_key}
         ],
         acc = {:ok, %{scope: {:function, "add_authorized_key", :actions}}}
       ) do
    {node, acc}
  end

  defp prewalk(
         node = {{:atom, arg}, _},
         acc = {:ok, %{scope: {:function, "add_authorized_key", :actions}}}
       )
       when arg in ["public_key", "encrypted_secret_key"],
       do: {node, acc}

  # Whitelist generics
  defp prewalk(true, acc = {:ok, _}), do: {true, acc}
  defp prewalk(false, acc = {:ok, _}), do: {false, acc}
  defp prewalk(number, acc = {:ok, _}) when is_number(number), do: {number, acc}
  defp prewalk(string, acc = {:ok, _}) when is_binary(string), do: {string, acc}
  defp prewalk(node = [do: _], acc = {:ok, _}), do: {node, acc}
  defp prewalk(node = {:do, _}, acc = {:ok, _}), do: {node, acc}
  defp prewalk(node = :do, acc = {:ok, _}), do: {node, acc}
  # Literals
  defp prewalk(node = {{:atom, key}, _, nil}, acc = {:ok, _}) when is_binary(key),
    do: {node, acc}

  defp prewalk(node = {:atom, key}, acc = {:ok, _}) when is_binary(key), do: {node, acc}

  # Whitelist interpolation of strings
  defp prewalk(
         node =
           {:<<>>, _, [{:"::", _, [{{:., _, [Kernel, :to_string]}, _, _}, {:binary, _, nil}]}, _]},
         acc
       ) do
    {node, acc}
  end

  defp prewalk(
         node =
           {:<<>>, _,
            [
              _,
              {:"::", _, [{{:., _, [Kernel, :to_string]}, _, _}, _]}
            ]},
         acc
       ) do
    {node, acc}
  end

  defp prewalk(node = {:"::", _, [{{:., _, [Kernel, :to_string]}, _, _}, _]}, acc) do
    {node, acc}
  end

  defp prewalk(node = {{:., _, [Kernel, :to_string]}, _, _}, acc) do
    {node, acc}
  end

  defp prewalk(node = {:., _, [Kernel, :to_string]}, acc) do
    {node, acc}
  end

  defp prewalk(node = Kernel, acc), do: {node, acc}
  defp prewalk(node = :to_string, acc), do: {node, acc}
  defp prewalk(node = {:binary, _, nil}, acc), do: {node, acc}

  defp prewalk(node, acc) when is_list(node) do
    {node, acc}
  end

  # Blacklist anything else
  defp prewalk(node, {:ok, _acc}) do
    throw({{:error, :unexpected_token}, node})
  end

  defp prewalk(node, e = {:error, _}), do: {node, e}

  # Reset the scope after actions triggered block ending
  defp postwalk(
         node =
           {{:atom, "actions"}, [line: _],
            [[{{:atom, "triggered_by"}, {{:atom, trigger_type}, _, _}} | opts], [do: actions]]},
         {:ok, acc}
       ) do
    actions =
      inject_bindings_and_functions(actions,
        bindings: %{
          "contract" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{}),
          "transaction" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})
        }
      )

    acc =
      case trigger_type do
        "datetime" ->
          [{{:atom, "at"}, timestamp}] = opts
          datetime = DateTime.from_unix!(timestamp)

          Map.update!(
            acc,
            :contract,
            &Contract.add_trigger(&1, :datetime, [at: datetime], actions)
          )

        "interval" ->
          [{{:atom, "at"}, interval}] = opts

          Map.update!(
            acc,
            :contract,
            &Contract.add_trigger(&1, :interval, [at: interval], actions)
          )

        "transaction" ->
          Map.update!(acc, :contract, &Contract.add_trigger(&1, :transaction, [], actions))

        "oracle" ->
          Map.update!(acc, :contract, &Contract.add_trigger(&1, :oracle, [], actions))
      end

    {node, {:ok, %{acc | scope: :root}}}
  end

  # Add conditions with brackets
  defp postwalk(
         node = {{:atom, "condition"}, _, [[{{:atom, condition_name}, conditions}]]},
         {:ok, acc}
       ) do
    bindings = Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})

    bindings =
      case condition_name do
        "inherit" ->
          Map.merge(bindings, %{
            "next" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{}),
            "previous" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})
          })

        _ ->
          Map.merge(bindings, %{
            "contract" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{}),
            "transaction" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})
          })
      end

    subject_scope = if condition_name == "inherit", do: "next", else: "transaction"

    conditions =
      inject_bindings_and_functions(conditions,
        bindings: bindings,
        subject: subject_scope
      )

    new_acc =
      acc
      |> Map.update!(
        :contract,
        &Contract.add_condition(
          &1,
          String.to_existing_atom(condition_name),
          aggregate_conditions(conditions, subject_scope)
        )
      )
      |> Map.put(:scope, :root)

    {node, {:ok, new_acc}}
  end

  # Add complex conditions with if statements
  defp postwalk(
         node =
           {{:atom, "condition"}, _,
            [
              {{:atom, condition_name}, _,
               [
                 conditions
               ]}
            ]},
         {:ok, acc}
       ) do
    subject_scope = if condition_name == "inherit", do: "next", else: "transaction"

    bindings = Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})

    bindings =
      case condition_name do
        "inherit" ->
          Map.merge(bindings, %{
            "next" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{}),
            "previous" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})
          })

        _ ->
          Map.merge(bindings, %{
            "contract" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{}),
            "transaction" => Enum.map(@transaction_fields, &{&1, ""}) |> Enum.into(%{})
          })
      end

    conditions =
      inject_bindings_and_functions(conditions,
        bindings: bindings,
        subject: subject_scope
      )

    new_acc =
      acc
      |> Map.update!(
        :contract,
        &Contract.add_condition(
          &1,
          String.to_existing_atom(condition_name),
          aggregate_conditions(conditions, subject_scope)
        )
      )
      |> Map.put(:scope, :root)

    {node, {:ok, new_acc}}
  end

  # Return to the parent scope after parsing the function call
  defp postwalk(node = {{:atom, _}, _, _}, {:ok, acc = %{scope: {:function, _, scope}}}) do
    {node, {:ok, %{acc | scope: scope}}}
  end

  # Convert Access key string to binary
  defp postwalk(
         {{:., meta1, [Access, :get]}, meta2,
          [{{:., meta3, [{subject, meta4, nil}, {:atom, field}]}, meta5, []}, {:atom, key}]},
         acc = {:ok, _}
       ) do
    {
      {{:., meta1, [Access, :get]}, meta2,
       [
         {{:., meta3, [{subject, meta4, nil}, String.to_existing_atom(field)]}, meta5, []},
         Base.decode16!(key, case: :mixed)
       ]},
      acc
    }
  end

  # Convert map key to binary
  defp postwalk({:%{}, meta, params}, acc = {:ok, _}) do
    encoded_params =
      Enum.map(params, fn
        {{:atom, key}, value} when is_binary(key) ->
          case Base.decode16(key, case: :mixed) do
            {:ok, bin} ->
              {bin, value}

            :error ->
              {key, value}
          end

        {key, value} ->
          {key, value}
      end)

    {{:%{}, meta, encoded_params}, acc}
  end

  defp postwalk(node, acc), do: {node, acc}

  defp valid_trigger_opts("datetime", [{{:atom, "at"}, timestamp}]) do
    if length(Integer.digits(timestamp)) != 10 do
      {:error, "invalid datetime"}
    else
      case DateTime.from_unix(timestamp) do
        {:ok, _} ->
          :ok

        _ ->
          {:error, "invalid datetime"}
      end
    end
  end

  defp valid_trigger_opts("interval", [{{:atom, "at"}, interval}]) do
    case CronParser.parse(interval) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        {:error, "invalid interval"}
    end
  end

  defp valid_trigger_opts("transaction", []), do: :ok
  defp valid_trigger_opts("oracle", []), do: :ok

  defp valid_trigger_opts(_, _), do: {:error, "unexpected token"}

  defp aggregate_conditions(conditions, subject_scope) do
    Enum.reduce(conditions, %Conditions{}, fn {subject, condition}, acc ->
      condition =
        if subject == "origin_family" do
          String.to_existing_atom(condition)
        else
          if is_binary(condition) or is_number(condition) do
            {:==, [],
             [
               {:get_in, [], [{:scope, [], nil}, [subject_scope, subject]]},
               condition
             ]}
          else
            Macro.postwalk(condition, &to_boolean_expression(&1, subject_scope, subject))
          end
        end

      Map.put(acc, String.to_existing_atom(subject), condition)
    end)
  end

  defp to_boolean_expression(
         {{:., metadata, [{:__aliases__, _, [:Library]}, fun]}, _, args},
         subject_scope,
         subject
       ) do
    arguments =
      if :erlang.function_exported(Library, fun, length(args)) do
        # If the number of arguments fullfill the function's arity  (without subject)
        args
      else
        [
          {:get_in, metadata, [{:scope, metadata, nil}, [subject_scope, subject]]} | args
        ]
      end

    if fun |> Atom.to_string() |> String.ends_with?("?") do
      {:==, metadata,
       [
         true,
         {{:., metadata, [{:__aliases__, [alias: Library], [:Library]}, fun]}, metadata,
          arguments}
       ]}
    else
      {:==, metadata,
       [
         {:get_in, metadata, [{:scope, metadata, nil}, [subject_scope, subject]]},
         {{:., metadata, [{:__aliases__, [alias: Library], [:Library]}, fun]}, metadata,
          arguments}
       ]}
    end
  end

  defp to_boolean_expression(condition = {:%{}, _, _}, subject_scope, subject) do
    {:==, [],
     [
       {:get_in, [], [{:scope, [], nil}, [subject_scope, subject]]},
       condition
     ]}
  end

  # Flatten comparison operations
  defp to_boolean_expression({op, _, [{:==, metadata, [{:get_in, _, _}, comp_a]}, comp_b]}, _, _)
       when op in [:==, :>=, :<=] do
    {op, metadata, [comp_a, comp_b]}
  end

  defp to_boolean_expression(condition, _, _), do: condition

  @doc """

  ## Examples

      iex> Interpreter.execute_actions(%Contract{
      ...>   triggers: [
      ...>     %Contract.Trigger{
      ...>       type: :transaction,
      ...>       actions: {:=, [line: 2],
      ...>          [
      ...>            {:scope, [line: 2], nil},
      ...>            {:update_in, [line: 2],
      ...>             [
      ...>               {:scope, [line: 2], nil},
      ...>               ["contract"],
      ...>               {:&, [line: 2],
      ...>                [
      ...>                  {{:., [line: 2],
      ...>                    [
      ...>                      {:__aliases__,
      ...>                       [alias: Zaryn.Contracts.Interpreter.TransactionStatements],
      ...>                       [:TransactionStatements]},
      ...>                      :set_type
      ...>                    ]}, [line: 2], [{:&, [line: 2], [1]}, "transfer"]}
      ...>                ]}
      ...>             ]}
      ...>          ]}
      ...>     }
      ...>   ]
      ...> }, :transaction)
      %Contract{
        triggers: [
         %Trigger{actions: {
            :=,
            [{:line, 2}],
            [
              {:scope, [{:line, 2}], nil},
              {:update_in, [line: 2], [{:scope, [line: 2], nil}, ["contract"], {:&, [line: 2], [{{:., [line: 2], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_type]}, [line: 2], [{:&, [line: 2], [1]}, "transfer"]}]}]}
            ]
          },
          opts: [],
          type: :transaction}
        ],
        next_transaction: %Transaction{type: :transfer, data: %TransactionData{}}
      }

      iex> Interpreter.execute_actions(%Contract{
      ...>   triggers: [
      ...>     %Contract.Trigger{
      ...>       type: :transaction,
      ...>       actions: {:__block__, [], [
      ...>        {
      ...>          :=,
      ...>          [{:line, 2}],
      ...>          [
      ...>            {:scope, [{:line, 2}], nil},
      ...>            {:update_in, [line: 2], [
      ...>              {:scope, [line: 2], nil},
      ...>              ["contract"],
      ...>              {:&, [line: 2], [
      ...>                {{:., [line: 2], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_type]},
      ...>                [line: 2],
      ...>                [{:&, [line: 2], [1]}, "transfer"]}]
      ...>              }
      ...>            ]}
      ...>          ]
      ...>        },
      ...>        {
      ...>          :=,
      ...>          [line: 3],
      ...>          [
      ...>            {:scope, [line: 3], nil},
      ...>            {:update_in, [line: 3], [
      ...>              {:scope, [line: 3], nil},
      ...>              ["contract"],
      ...>              {:&, [line: 3], [
      ...>                {{:., [line: 3], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :add_zaryn_transfer]},
      ...>                [line: 3], [{:&, [line: 3], [1]},
      ...>                [{"to", {{:., [line: 3], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library], [:Library]}, :hash]}, [line: 3], ["@Alice2"]}}, {"amount", 10.04}]]}
      ...>              ]}
      ...>            ]}
      ...>          ]
      ...>        }
      ...>      ]},
      ...>  }]}, :transaction)
      %Contract{
        triggers: [
          %Trigger{
            actions: {:__block__, [], [
              {
                :=,
                [{:line, 2}],
                [
                  {:scope, [{:line, 2}], nil},
                  {:update_in, [line: 2], [
                    {:scope, [line: 2], nil},
                    ["contract"],
                    {:&, [line: 2], [
                      {{:., [line: 2], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :set_type]},
                      [line: 2],
                      [{:&, [line: 2], [1]}, "transfer"]}]
                    }
                  ]}
                ]
              },
              {
                :=,
                [line: 3],
                [
                  {:scope, [line: 3], nil},
                  {:update_in, [line: 3], [
                    {:scope, [line: 3], nil},
                    ["contract"],
                    {:&, [line: 3], [
                      {{:., [line: 3], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.TransactionStatements], [:TransactionStatements]}, :add_zaryn_transfer]},
                      [line: 3], [{:&, [line: 3], [1]},
                      [{"to", {{:., [line: 3], [{:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library], [:Library]}, :hash]}, [line: 3], ["@Alice2"]}}, {"amount", 10.04}]]}
                    ]}
                  ]}
                ]
              }
            ]},
            opts: [],
            type: :transaction
          }
        ],
        next_transaction: %Transaction{
          type: :transfer,
          data: %TransactionData{
              ledger: %Ledger{
                zaryn: %ZARYNLedger{
                  transfers: [
                    %ZARYNLedger.Transfer{ to: <<0, 252, 103, 8, 52, 151, 127, 195, 65, 104, 171, 247, 238, 227, 111, 140, 89,
                      49, 204, 58, 141, 215, 66, 253, 40, 183, 165, 117, 120, 80, 100, 232, 95>>, amount: 10.04}
                  ]
                }
              }
          }
        }
      }
  """
  def execute_actions(contract = %Contract{triggers: triggers}, trigger_type, constants \\ %{}) do
    %Contract.Trigger{actions: quoted_code} = Enum.find(triggers, &(&1.type == trigger_type))

    {%{"contract" => contract}, _} =
      Code.eval_quoted(quoted_code, scope: Map.put(constants, "contract", contract))

    contract
  end

  @doc """
  Execute abritary code using some constants as bindings

  ## Examples

        iex> Interpreter.execute({{:., [line: 1],
        ...> [
        ...>   {:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library],
        ...>    [:Library]},
        ...>   :regex_match?
        ...> ]}, [line: 1],
        ...> [{:get_in, [line: 1], [{:scope, [line: 1], nil}, ["content"]]}, "abc"]}, %{ "content" => "abc"})
        true

        iex> Interpreter.execute({:==, [],
        ...> [
        ...>   {:get_in, [line: 1], [{:scope, [line: 1], nil}, ["next_transaction", "content"]]},
        ...>   {:get_in, [line: 1], [{:scope, [line: 1], nil}, ["previous_transaction", "content"]]},
        ...> ]}, %{ "previous_transaction" => %{"content" => "abc"}, "next_transaction" => %{ "content" => "abc" } })
        true

        iex> Interpreter.execute({{:., [line: 2],
        ...> [
        ...>    {:__aliases__, [alias: Zaryn.Contracts.Interpreter.Library],
        ...>     [:Library]},
        ...>    :hash
        ...>  ]}, [line: 2],
        ...> [{:get_in, [line: 2], [{:scope, [line: 2], nil}, ["content"]]}]}, %{ "content" => "abc" })
        <<0, 186, 120, 22, 191, 143, 1, 207, 234, 65, 65, 64, 222, 93, 174, 34, 35, 176, 3, 97, 163, 150, 23, 122, 156, 180, 16, 255, 97, 242, 0, 21, 173>>
  """
  def execute(quoted_code, constants = %{}) do
    {res, _} = Code.eval_quoted(quoted_code, scope: constants)
    res
  end

  defp inject_bindings_and_functions(quoted_code, opts) when is_list(opts) do
    bindings = Keyword.get(opts, :bindings, %{})
    subject = Keyword.get(opts, :subject)

    {ast, _} =
      Macro.postwalk(
        quoted_code,
        %{
          bindings: bindings,
          library_functions: @library_functions_names,
          transaction_statements_functions: @transaction_statements_functions_names,
          subject: subject
        },
        &do_postwalk_execution/2
      )

    ast
  end

  defp do_postwalk_execution({:=, metadata, [var_name, content]}, acc) do
    put_ast =
      {{:., metadata, [{:__aliases__, metadata, [:Map]}, :put]}, metadata,
       [{:scope, metadata, nil}, var_name, parse_value(content)]}

    {
      {:=, metadata, [{:scope, metadata, nil}, put_ast]},
      put_in(acc, [:bindings, var_name], parse_value(content))
    }
  end

  defp do_postwalk_execution(_node = {{:atom, atom}, metadata, args}, acc)
       when atom in @library_functions_names do
    {{{:., metadata, [{:__aliases__, [alias: Library], [:Library]}, String.to_atom(atom)]},
      metadata, args}, acc}
  end

  defp do_postwalk_execution(_node = {{:atom, atom}, metadata, args}, acc)
       when atom in @transaction_statements_functions_names do
    args =
      Enum.map(args, fn arg ->
        {ast, _} = Macro.postwalk(arg, acc, &do_postwalk_execution/2)
        ast
      end)

    ast = {
      {:., metadata,
       [
         {:__aliases__, [alias: TransactionStatements], [:TransactionStatements]},
         String.to_atom(atom)
       ]},
      metadata,
      [{:&, metadata, [1]} | args]
    }

    update_ast =
      {:update_in, metadata,
       [
         {:scope, metadata, nil},
         ["contract"],
         {:&, metadata,
          [
            ast
          ]}
       ]}

    {
      {:=, metadata, [{:scope, metadata, nil}, update_ast]},
      acc
    }
  end

  defp do_postwalk_execution(
         _node = {{:atom, atom}, metadata, _args},
         acc = %{bindings: bindings, subject: subject}
       ) do
    if Map.has_key?(bindings, atom) do
      search =
        case subject do
          nil ->
            [atom]

          subject ->
            # Do not use the subject when using reserved keyword
            if atom in ["contract", "transaction", "next", "previous"] do
              [atom]
            else
              [subject, atom]
            end
        end

      {
        {:get_in, metadata, [{:scope, metadata, nil}, search]},
        acc
      }
    else
      {atom, acc}
    end
  end

  defp do_postwalk_execution({:., metadata, [parent, {{:atom, field}}]}, acc) do
    {
      {:get_in, metadata, [{:scope, metadata, nil}, [parent, parse_value(field)]]},
      acc
    }
  end

  defp do_postwalk_execution(
         {:., _, [{:get_in, metadata, [{:scope, _, nil}, access]}, {:atom, field}]},
         acc
       ) do
    {
      {:get_in, metadata, [{:scope, metadata, nil}, access ++ [parse_value(field)]]},
      acc
    }
  end

  defp do_postwalk_execution(
         {:., metadata,
          [{:get_in, metadata, [{:scope, metadata, nil}, [parent]]}, {:atom, child}]},
         acc
       ) do
    {{:get_in, metadata, [{:scope, metadata, nil}, [parent, parse_value(child)]]}, acc}
  end

  defp do_postwalk_execution({{:atom, atom}, val}, acc) do
    {ast, _} = Macro.postwalk(val, acc, &do_postwalk_execution/2)
    {{atom, ast}, acc}
  end

  defp do_postwalk_execution({{:get_in, metadata, [{:scope, metadata, nil}, access]}, _, []}, acc) do
    {
      {:get_in, metadata, [{:scope, metadata, nil}, access]},
      acc
    }
  end

  defp do_postwalk_execution({:==, _, [{left, _, args_l}, {right, _, args_r}]}, acc) do
    {{:==, [], [{left, [], args_l}, {right, [], args_r}]}, acc}
  end

  defp do_postwalk_execution({:==, _, [{left, _, args}, right]}, acc) do
    {{:==, [], [{left, [], args}, right]}, acc}
  end

  defp do_postwalk_execution({node, _, _}, acc) when is_binary(node) do
    {parse_value(node), acc}
  end

  defp do_postwalk_execution(node, acc), do: {parse_value(node), acc}

  defp parse_value(val) when is_binary(val) do
    case Base.decode16(val) do
      {:ok, bin} ->
        bin

      _ ->
        val
    end
  end

  defp parse_value(val), do: val

  @spec valid_conditions?(Conditions.t(), map()) :: boolean()
  def valid_conditions?(conditions = %Conditions{}, constants = %{}) do
    result =
      conditions
      |> Map.from_struct()
      |> Enum.all?(&match?({_, true}, validate_condition(&1, constants)))

    if result do
      result
    else
      result
    end
  end

  defp validate_condition({:origin_family, _}, _) do
    # Skip the verification
    # The Proof of Work algorithm will use this condition to verify the transaction
    {:origin_family, true}
  end

  defp validate_condition({:previous_public_key, nil}, _) do
    # Skip the verification as previous public key change for each transaction
    {:previous_public_key, true}
  end

  # Validation rules for inherit constraints
  defp validate_condition({field, nil}, %{"previous" => prev, "next" => next}) do
    {field, Map.get(prev, Atom.to_string(field)) == Map.get(next, Atom.to_string(field))}
  end

  defp validate_condition({field, condition}, constants = %{"next" => next}) do
    result = execute(condition, constants)

    if is_boolean(result) do
      {field, result}
    else
      {field, Map.get(next, Atom.to_string(field)) == result}
    end
  end

  # Validation rules for incoming transaction
  defp validate_condition({field, nil}, %{"transaction" => _}) do
    # Skip the validation if no transaction conditions are provided
    {field, true}
  end

  defp validate_condition(
         {field, condition},
         constants = %{"transaction" => transaction}
       ) do
    result = execute(condition, constants)

    if is_boolean(result) do
      {field, result}
    else
      {field, Map.get(transaction, Atom.to_string(field)) == result}
    end
  end
end
