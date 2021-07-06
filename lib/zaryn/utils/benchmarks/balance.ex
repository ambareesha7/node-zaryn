defmodule Zaryn.Benchmark.Balance do
  @moduledoc """
  Benchmark balance
  """

  require Logger

  alias Zaryn.Benchmark
  alias Zaryn.Crypto
  alias Zaryn.P2P.Message
  alias Zaryn.P2P.Message.GetBalance
  alias Zaryn.Utils
  alias Zaryn.WebClient

  @behaviour Benchmark

  def plan([host | _nodes], _opts) do
    port = Application.get_env(:zaryn, Zaryn.P2P.Endpoint)[:port]
    http = Application.get_env(:zaryn, ZarynWeb.Endpoint)[:http][:port]
    {:ok, addr} = :inet.getaddr(to_charlist(host), :inet)

    {:ok, sock} = :socket.open(:inet, :stream, :tcp)
    :ok = :socket.connect(sock, %{family: :inet, port: port, addr: addr})

    {%{
       "P2P socket" => fn _ -> get_balance_p2p_socket(addr, port) end,
       "P2P gentcp" => fn _ -> get_balance_p2p_gentcp(addr, port) end,
       "P2P attach" => fn _ -> get_balance_p2p(sock) end,
       "WEB" => fn _ -> get_balance_web(host, http) end
     },
     [
       before_scenario: fn _ -> get_vm_status(host, http) end,
       after_scenario: fn before ->
         now = get_vm_status(host, http)

         [{"vm_system_counts_process_count", 20}]
         |> Enum.each(fn {metric, delta} ->
           Logger.info("Checking #{metric} #{before[metric]} vs #{now[metric]}")

           if before[metric] + delta - now[metric] < 0 do
             raise RuntimeError, message: "leak of #{metric} is detected"
           end
         end)
       end
     ]}
  end

  defp get_vm_status(host, port) do
    {:ok, data} = WebClient.with_connection(host, port, &WebClient.request(&1, "GET", "/metrics"))

    data
    |> :erlang.iolist_to_binary()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "vm_"))
    |> Enum.map(fn kv ->
      [k, v] = String.split(kv)
      {k, v |> Integer.parse() |> elem(0)}
    end)
    |> Enum.into(%{})
  end

  @genesis Application.compile_env!(:zaryn, Zaryn.Bootstrap.NetworkInit)[:genesis_pools]
  @balance @genesis[:foundation][:amount]
  @address @genesis[:foundation][:public_key] |> Base.decode16!(case: :mixed) |> Crypto.hash()
  @message %GetBalance{address: @address} |> Message.encode() |> Utils.wrap_binary()
  @msgdata <<byte_size(@message) + 4::32, 1::32, @message::binary>>

  defp get_balance_p2p_socket(addr, port) do
    {:ok, sock} = :socket.open(:inet, :stream, :tcp)
    :ok = :socket.connect(sock, %{family: :inet, port: port, addr: addr})
    :ok = :socket.send(sock, @msgdata)
    {:ok, <<_::32, _::32, data::binary>>} = :socket.recv(sock, 0, 1000)
    :ok = :socket.close(sock)

    {%Zaryn.P2P.Message.Balance{nft: %{}, zaryn: @balance}, ""} = Message.decode(data)

    :ok
  end

  defp get_balance_p2p(sock) do
    :ok = :socket.send(sock, @msgdata)
    {:ok, <<_::32, _::32, data::binary>>} = :socket.recv(sock, 0, 1000)

    {%Zaryn.P2P.Message.Balance{nft: %{}, zaryn: @balance}, ""} = Message.decode(data)

    :ok
  end

  defp get_balance_p2p_gentcp(addr, port) do
    {:ok, sock} = :gen_tcp.connect(addr, port, [:binary])
    :ok = :gen_tcp.send(sock, @msgdata)

    receive do
      {:tcp, ^sock, <<_::32, _::32, data::binary>>} ->
        :ok = :gen_tcp.close(sock)

        {%Zaryn.P2P.Message.Balance{nft: %{}, zaryn: @balance}, ""} = Message.decode(data)

        :ok
    after
      1000 -> raise "timeout"
    end
  end

  @graphql """
  query {balance(address: "#{@address |> Base.encode16()}"){zaryn}}
  """

  defp get_balance_web(host, port) do
    {:ok, %{"data" => %{"balance" => %{"zaryn" => @balance}}}} =
      WebClient.with_connection(host, port, &WebClient.query(&1, @graphql))
  end
end
