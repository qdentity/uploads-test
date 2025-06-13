defmodule UploadsWeb.UploadLive do
  @moduledoc false
  use UploadsWeb, :live_view

  @accept ~w(.zip .jpg .jpeg .png)
  @max_file_size 20_000_000_000

  def root do
    case Application.get_env(:uploads, :uploads_path) do
      nil -> Application.app_dir(:uploads, "priv/static/uploads")
      path -> path
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:done, false)
     |> assign(:form, to_form(%{}))
     |> assign(:uploaded_files, list_uploads!())
     |> allow_upload(:archive, accept: @accept, max_entries: 4, max_file_size: @max_file_size, chunk_size: 2_097_152)}
  end

  defp list_uploads! do
    root()
    |> File.ls!()
    |> Enum.map(fn filename ->
      root() |> Path.join(filename) |> to_upload()
    end)
  end

  defp to_upload(path) do
    %{
      path: path,
      src: ~p"/uploads/#{Path.basename(path)}",
      size: file_size(path)
    }
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :archive, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    {:noreply,
     socket
     |> push_event("confetti", %{})
     |> update(:uploaded_files, &(&1 ++ process_uploads(socket)))}
  end

  defp process_uploads(socket) do
    consume_uploaded_entries(socket, :archive, fn %{path: tmp}, e ->
      path = Path.join(root(), e.client_name)
      File.cp!(tmp, path)
      {:ok, to_upload(path)}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@done}>
      <h1 class="w-full text-center text-3xl font-bold text-emerald-600 absolute top-[40%] left-0">
        Done!
      </h1>
    </div>
    <.form :if={not @done} for={@form} phx-submit="save" phx-change="validate">
      <h2 class="font-bold text-2xl">Upload new</h2>

      <div class="my-3">
        <.live_file_input upload={@uploads.archive} />
      </div>

      <div phx-drop-target={@uploads.archive.ref} class="mb-3">
        <h3 :if={@uploads.archive.entries != []} class="font-bold text-lg">Queue</h3>
        <div :for={entry <- @uploads.archive.entries}>
          <div class="flex gap-3 my-1">
            <progress value={entry.progress} max="100" class="flex-grow">{entry.progress}%</progress>
            <button type="button" phx-click="cancel" phx-value-ref={entry.ref} aria-label="cancel">
              &times;
            </button>
          </div>
          <p
            :for={err <- upload_errors(@uploads.archive, entry)}
            class="text-red-600 px-2 py-1 bg-red-100"
          >
            {error_to_string(err)}
          </p>
        </div>

        <p :for={err <- upload_errors(@uploads.archive)} class="text-red-600 px-2 py-1 bg-red-100">
          {error_to_string(err)}
        </p>
      </div>

      <.button>Upload!</.button>
    </.form>
    <div class="mt-10">
      <h2 class="font-bold text-2xl my-2">Uploads</h2>

      <div class="flex flex-wrap gap-1">
        <div
          :for={u <- @uploaded_files}
          class="bg-gray-100 aspect-square w-[200px] shrink-0 flex flex-col justify-center items-center"
        >
          <p class="font-bold">{Path.basename(u.path)}</p>
          <p><span title={"#{u.size} bytes"}>{format_bytes(u.size)}</span></p>
        </div>
      </div>
    </div>
    """
  end

  def file_size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> size
      {:error, _reason} -> :NaN
    end
  end

  def count_files(path) do
    if String.ends_with?(path, ".zip") do
      case :zip.list_dir(to_charlist(path)) do
        {:ok, files} -> length(files)
        {:error, _reason} -> -1
      end
    end
  end

  @units ["bytes", "kB", "MB", "GB", "TB", "PB"]

  def format_bytes(atom) when is_atom(atom), do: "#{atom} bytes"

  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    format(bytes, 0)
  end

  defp format(bytes, unit_index) when bytes < 1024 or unit_index == length(@units) - 1 do
    value = Float.round(bytes, 2)
    "#{value} #{@units |> Enum.at(unit_index)}"
  end

  defp format(bytes, unit_index) do
    format(bytes / 1024, unit_index + 1)
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
end
