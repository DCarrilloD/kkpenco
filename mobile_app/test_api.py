
import flet as ft
import logging

# Configure logging to write to file
logging.basicConfig(filename='api_inspection.log', level=logging.INFO)

def main(page: ft.Page):
    page.add(ft.Text("Inspecting Storage API..."))
    
    if hasattr(page, "shared_preferences"):
        sp = page.shared_preferences
        logging.info(f"SP Object: {sp}")
        logging.info(f"SP Type: {type(sp)}")
        logging.info(f"SP Dir: {dir(sp)}")
    else:
        logging.error("No shared_preferences found")

    page.window_close()

ft.app(target=main)
