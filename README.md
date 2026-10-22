# ToDo Flutter App

A beginner-friendly Flutter To-Do application with local storage.

## Features
- Add, edit, and delete tasks
- Mark tasks complete or pending
- Search task titles and descriptions
- Filter by All, Today, Important, Pending, and Completed
- Low / Medium / High priority
- Optional due dates
- Undo after deleting a task
- Clear all completed tasks
- Saves tasks on the device with `shared_preferences`

## Run it
1. Install Flutter and make sure `flutter doctor` has no blocking issues.
2. Extract this folder.
3. Open a terminal in this folder (the folder containing `pubspec.yaml`).
4. Run:

   ```bash
   flutter pub get
   flutter run
   ```

## Important
This starter uses local device storage, not a cloud database or user accounts. Data is saved on the device where the app runs.
