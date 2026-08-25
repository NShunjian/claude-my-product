import React from 'react'

interface ToastProps {
  message: string
  visible: boolean
}

const Toast: React.FC<ToastProps> = ({ message, visible }) => {
  if (!visible) return null

  return (
    <div className="fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2 rounded-full bg-black/70 px-4 py-2 text-sm text-white shadow-lg transition-opacity">
      {message}
    </div>
  )
}

export default Toast
