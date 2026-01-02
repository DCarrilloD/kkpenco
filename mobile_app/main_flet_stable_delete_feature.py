import sys
import os
import flet as ft
from datetime import datetime

# Añadir path para encontrar imports
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)
sys.path.append(os.path.join(current_dir, 'src'))

# Imports locales (si fallan, se usarán mocks)
try:
    from shared.models import Consistency, KKEvent
    from kkcos.api import APIClient
except ImportError:
    print("Warning: Local imports failed. Using mocks.")
    Consistency = None
    KKEvent = None
    APIClient = None

# --- Constants ---
BG_COLOR = "#000000"
CARD_COLOR = "#1C1C1E"
ACCENT_COLOR = "#C67C4E" # Modern Brown
TEXT_COLOR = "#FFFFFF"

def main(page: ft.Page):
    page.title = "KKCoS"
    page.theme_mode = ft.ThemeMode.DARK
    page.bgcolor = BG_COLOR
    page.padding = 10
    
    # Intentar inicializar API
    api = None
    if APIClient:
        try:
            api = APIClient()
        except:
            pass

    # --- Views ---
    
    def view_tracker():
        # State for consistency (default Normal)
        selected_cons = ["Normal"] 

        # Helper to update button styles
        def update_buttons():
            val = selected_cons[0]
            btn_normal.bgcolor = ACCENT_COLOR if val == "Normal" else "#424242"
            btn_normal.color = "black" if val == "Normal" else TEXT_COLOR
            
            btn_jurasica.bgcolor = ACCENT_COLOR if val == "Jurásica" else "#424242"
            btn_jurasica.color = "black" if val == "Jurásica" else TEXT_COLOR

            btn_espurruteo.bgcolor = ACCENT_COLOR if val == "Espurruteo" else "#424242"
            btn_espurruteo.color = "black" if val == "Espurruteo" else TEXT_COLOR
            page.update()

        def set_cons(e):
            selected_cons[0] = e.control.data
            update_buttons()

        # Buttons definition
        button_style = ft.ButtonStyle(text_style=ft.TextStyle(size=16, weight="bold"))
        btn_normal = ft.FilledButton("Normal", data="Normal", on_click=set_cons, bgcolor=ACCENT_COLOR, color="black", width=135, height=60, style=button_style)
        btn_jurasica = ft.FilledButton("Jurásica", data="Jurásica", on_click=set_cons, bgcolor="#424242", color=TEXT_COLOR, width=135, height=60, style=button_style)
        btn_espurruteo = ft.FilledButton("Espurruteo", data="Espurruteo", on_click=set_cons, bgcolor="#424242", color=TEXT_COLOR, width=135, height=60, style=button_style)

        notes_txt = ft.TextField(label="Notas", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=10)

        def on_log(e):
            if not api:
                page.snack_bar = ft.SnackBar(ft.Text("Modo Offline: KK guardada localmente (simulación)."))
                page.snack_bar.open = True
                page.update()
                return

            try:
                # Create Event Object
                # Map string to Enum if possible, or pass string direct since it is str, Enum
                # Ensure we use the shared model if available
                
                new_event = KKEvent(
                    user_id=1, # Mock User ID
                    consistency=Consistency(selected_cons[0]), # Explicit Enum cast
                    notes=notes_txt.value or "",
                    timestamp=datetime.now(datetime.UTC)
                )
                
                success = api.create_event(new_event)
                
                if success:
                    page.snack_bar = ft.SnackBar(ft.Text(f"¡Éxito! KK {selected_cons[0]} registrada en la nube."))
                    notes_txt.value = "" # Clear notes
                else:
                    page.snack_bar = ft.SnackBar(ft.Text("Error: No se pudo conectar con el servidor."))
            
            except Exception as ex:
                page.snack_bar = ft.SnackBar(ft.Text(f"Error desconocido: {str(ex)}"))
            
            page.snack_bar.open = True
            page.update()
        
        return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Container(height=10), # Small spacer from top
                
                # Main Button "KKApenco"
                ft.Container(
                    alignment=ft.Alignment(0, 0),
                    content=ft.Column(
                        horizontal_alignment="center",
                        controls=[
                            ft.FilledButton(
                                "KKApenco",
                                icon="add",
                                bgcolor=ACCENT_COLOR,
                                color="black",
                                style=ft.ButtonStyle(
                                    shape=ft.RoundedRectangleBorder(radius=20),
                                    padding=20,
                                    text_style=ft.TextStyle(size=20, weight="bold")
                                ),
                                width=220,
                                height=70,
                                on_click=on_log
                            )
                        ]
                    )
                ),
                ft.Container(height=30),
                
                # Details Form
                ft.Container(
                    bgcolor=CARD_COLOR,
                    padding=30, # More padding
                    border_radius=25,
                    margin=ft.Margin.symmetric(horizontal=15), # Responsive margin
                    alignment=ft.Alignment(0, 0),
                    content=ft.Column([
                        ft.Text("Registra tu caca", size=28, weight="bold", text_align="center"),
                        
                        # Image Placeholder
                        ft.Container(
                            height=180, # Bigger image area
                            bgcolor="#8A000000", # Black54 substitute
                            border_radius=15,
                            alignment=ft.Alignment(0, 0),
                            content=ft.Icon("image", size=60, color="grey"), # Bigger icon
                            margin=ft.Margin.only(bottom=20)
                        ),

                        # Consistency Buttons Row
                        ft.Text("Consistencia", size=18, color=TEXT_COLOR), # Bigger label
                        ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_EVENLY,
                            controls=[
                                btn_normal,
                                btn_jurasica,
                                btn_espurruteo
                            ],
                            wrap=True,
                            spacing=10
                        ),
                        
                        ft.Container(height=15),
                        ft.TextField(label="Notas", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=15, text_size=16, content_padding=20),
                        ft.Container(height=15),
                        
                        ft.FilledButton(
                            on_click=on_log, 
                            bgcolor=ACCENT_COLOR, 
                            color="black", 
                            width=None, # Auto width to fill container?
                            expand=True, # Needs to be in a row/col with expansion logic usually, but in Column it fills width if cross_alignment is stretch.
                            # But here cross_alignment is center. 
                            # Let's set a very large width so it gets clamped by container padding.
                            style=ft.ButtonStyle(
                                shape=ft.RoundedRectangleBorder(radius=15),
                                padding=15,
                            ),
                            height=60,
                            content=ft.Text("Guardar KK", size=20, weight="bold")
                        ),
                        ft.Container(height=15),
                        ft.FilledButton(
                            on_click=lambda _: on_nav_tap(4), # Go to History
                            bgcolor="#333333", 
                            color="white", 
                            style=ft.ButtonStyle(
                                shape=ft.RoundedRectangleBorder(radius=15),
                                padding=15,
                            ),
                            height=50,
                            content=ft.Text("Revisa tu mierda", size=18, weight="bold")
                        )
                    ], horizontal_alignment=ft.CrossAxisAlignment.STRETCH) # Stretch content to fill container
                )
            ]
        )

    def view_ranking():
        return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Text("Ranking", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(
                    expand=True, 
                    bgcolor=CARD_COLOR, 
                    border_radius=15,
                    alignment=ft.Alignment(0, 0),
                    content=ft.Text("Top Cacas\n(Próximamente)", text_align="center")
                )
            ]
        )

    def view_history():
        header = ft.Text("Tu Mierda", size=28, weight="bold", color=TEXT_COLOR, text_align="center")
        
        # Container for the list
        list_container = ft.ListView(expand=True, spacing=10, padding=20)

        # Helper to delete item
        def delete_item(e):
             event_id = e.control.data
             if api and api.delete_event(event_id):
                 page.snack_bar = ft.SnackBar(ft.Text("KK eliminada correctamente."))
                 page.snack_bar.open = True
                 # Refresh list logic: simplest way is to re-render the view
                 # Ideally we should manipulate the list control, but reloading view is easier for now
                 on_nav_tap(4) 
             else:
                 page.snack_bar = ft.SnackBar(ft.Text("Error al eliminar KK."))
                 page.snack_bar.open = True
                 page.update()
        
        if not api:
            list_container.controls.append(ft.Text("Modo Offline (Sin conexión)", color="red", text_align="center"))
        else:
            try:
                data = api.get_events()
                if not data:
                    list_container.controls.append(
                        ft.Container(
                            padding=40,
                            content=ft.Text("Aún no hay registros.\n¡Estrena el trono!", text_align="center", color="grey")
                        )
                    )
                else:
                    # Show newest first
                    for item in reversed(data):
                        timestamp = item.get("timestamp", "")
                        display_time = timestamp.replace("T", " ")[:16]
                        consistency = item.get("consistency", "N/A")
                        notes = item.get("notes") or "Sin notas"
                        event_id = item.get("id")
                        
                        card = ft.Container(
                            bgcolor=CARD_COLOR,
                            padding=15,
                            border_radius=15,
                            content=ft.Column([
                                ft.Row([
                                    # Delete Button
                                    ft.IconButton(
                                        icon=ft.icons.Icons.CLOSE, 
                                        icon_color="red",
                                        data=event_id, 
                                        on_click=delete_item,
                                        tooltip="Eliminar registro"
                                    ),
                                    # Info
                                    ft.Column([
                                        ft.Text(consistency, weight="bold", size=18, color=ACCENT_COLOR),
                                        ft.Text(display_time, size=12, color="grey")
                                    ], expand=True), # Expand text column so button stays left
                                ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                                
                                ft.Container(height=5),
                                ft.Text(notes, size=15, color=TEXT_COLOR, italic=True if notes == "Sin notas" else False)
                            ])
                        )
                        list_container.controls.append(card)
                        
            except Exception as e:
                list_container.controls.append(ft.Text(f"Error al cargar datos: {str(e)}", color="red"))

        return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Container(height=10),
                header,
                ft.Container(expand=True, content=list_container), # Use expand to fill remaining space
                ft.Container(height=20, content=ft.ElevatedButton("Volver", on_click=lambda _: on_nav_tap(0), bgcolor="#333", color="white"))
            ]
        )

    def view_cos():
         return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Text("COS", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(
                    expand=True, 
                    bgcolor=CARD_COLOR, 
                    border_radius=15,
                    alignment=ft.Alignment(0, 0),
                    content=ft.Text("Página COS en construcción", text_align="center", size=18, color="grey")
                )
            ]
        )

    def view_profile():
        return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Text("Perfil", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(
                    bgcolor=CARD_COLOR,
                    padding=20,
                    border_radius=15,
                    width=300,
                    content=ft.Text("Configuración y Logros", text_align="center")
                )
            ]
        )

    # --- Custom Navigation Logic ---
    
    body = ft.Container(expand=True)

    def set_page_content(index):
        if index == 0: body.content = view_tracker()
        elif index == 1: body.content = view_ranking()
        elif index == 2: body.content = view_cos() # New empty COS view
        elif index == 3: body.content = view_profile()
        elif index == 4: body.content = view_history() # Hidden history view
        page.update()

    def create_nav_item(icon_name, label, index, current_index):
        # Don't highlight if current_index is outside nav range (e.g. 4)
        is_active = (index == current_index)
        color = ACCENT_COLOR if is_active else "#888888"
        return ft.Container(
            content=ft.Column(
                [
                    ft.Icon(icon_name, color=color, size=26),
                    ft.Text(label, color=color, size=11, weight="bold")
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2
            ),
            on_click=lambda e: on_nav_tap(index),
            expand=True,
            padding=5,
            ink=True
        )

    def render_nav_bar(current_index):
        return ft.Container(
            bgcolor=CARD_COLOR,
            height=70,  # Fixed height for internal stability
            padding=ft.Padding.only(bottom=10, top=5),
            border_radius=ft.BorderRadius.only(top_left=15, top_right=15),
            content=ft.Row(
                controls=[
                    create_nav_item("touch_app", "KKpenco", 0, current_index),
                    create_nav_item("leaderboard", "Ranking", 1, current_index),
                    create_nav_item("groups", "COS", 2, current_index),
                    create_nav_item("person", "Perfil", 3, current_index),
                ],
                alignment=ft.MainAxisAlignment.SPACE_AROUND,
                vertical_alignment=ft.CrossAxisAlignment.CENTER
            )
        )

    nav_bar_container = ft.Container() # Holds the Nav Bar specifically

    def on_nav_tap(index):
        set_page_content(index)
        nav_bar_container.content = render_nav_bar(index)
        nav_bar_container.update()

    # Initial Setup
    nav_bar_container.content = render_nav_bar(0)
    set_page_content(0)

    # Main Layout
    page.add(
        ft.Column(
            controls=[
                body,              # Takes all free space
                nav_bar_container  # Stays at bottom
            ],
            expand=True,
            spacing=0
        )
    )

if __name__ == "__main__":
    ft.app(main)
