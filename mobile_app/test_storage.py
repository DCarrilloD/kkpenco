
import flet as ft
import logging

logging.basicConfig(level=logging.DEBUG)

def main(page: ft.Page):
    page.add(ft.Text("Testing Storage"))
    
    print("Page dir:", dir(page))
    
    if hasattr(page, "client_storage"):
        print("client_storage exists")
    else:
        print("client_storage MISSING")

    if hasattr(page, "shared_preferences"):
        print("shared_preferences exists")
        print("shared_preferences dir:", dir(page.shared_preferences))
        try:
            sp = page.shared_preferences
            print(f"SP Type: {type(sp)}")
        except Exception as e:
            print(f"Error accessing shared_preferences: {e}")
            
    page.update()

ft.app(target=main)
